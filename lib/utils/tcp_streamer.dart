import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import '../globals.dart';

class TCPStreamer {
  SendPort? _sendPort;
  Isolate? _isolate;

  Future<void> init() async {
    if (_sendPort != null) return;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_tcpIsolate, {
      'port': receivePort.sendPort,
      'targetIP': hPi4Global.tcpTargetIP,
      'targetPort': hPi4Global.tcpTargetPort,
    });

    _sendPort = await receivePort.first as SendPort;
  }

  void streamBatch(String type, List<dynamic> samples) {
    _sendPort?.send({'type': type, 'samples': samples});
  }

  void sendData(String message) {
    _sendPort?.send(message);
  }

  void close() {
    _sendPort?.send(null); // Signal isolate to close
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
  }

  static void _tcpIsolate(Map<String, dynamic> args) async {
    final SendPort mainSendPort = args['port'];
    final String targetIP = args['targetIP'];
    final int targetPort = args['targetPort'];

    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    Socket? socket;
    try {
      socket = await Socket.connect(targetIP, targetPort, timeout: const Duration(seconds: 5));
      print("TCP Streamer connected to $targetIP:$targetPort");
    } catch (e) {
      print("Failed to connect TCP socket in isolate: $e");
      // Still need to listen to commandPort to avoid blocking the main thread if it sends messages,
      // or we could signal failure back. For now, we'll just consume and ignore.
    }

    await for (final message in commandPort) {
      if (message == null) break;
      if (socket == null) continue;

      String? payload;
      if (message is String) {
        payload = message;
      } else if (message is Map) {
        final String type = message['type'];
        final List<dynamic> samples = message['samples'];
        payload = samples.map((s) => "$type,$s").join("\n");
      }

      if (payload != null && payload.isNotEmpty) {
        try {
          socket.write("$payload\n");
          await socket.flush();
        } catch (e) {
          print("Error sending TCP data from isolate: $e");
          break; // Exit on socket error
        }
      }
    }
    await socket?.close();
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import '../globals.dart';

class UDPStreamer {
  SendPort? _sendPort;
  Isolate? _isolate;

  Future<void> init() async {
    if (_sendPort != null) return;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_udpIsolate, {
      'port': receivePort.sendPort,
      'targetIP': hPi4Global.udpTargetIP,
      'targetPort': hPi4Global.udpTargetPort,
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

  static void _udpIsolate(Map<String, dynamic> args) async {
    final SendPort mainSendPort = args['port'];
    final String targetIP = args['targetIP'];
    final int targetPort = args['targetPort'];

    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      print("Failed to bind UDP socket in isolate: $e");
      return;
    }

    await for (final message in commandPort) {
      if (message == null) break;
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
          final List<int> data = utf8.encode(payload);
          socket.send(data, InternetAddress(targetIP), targetPort);
        } catch (e) {
          print("Error sending UDP data from isolate: $e");
        }
      }
    }
    socket.close();
  }
}

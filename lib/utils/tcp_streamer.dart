import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../globals.dart';

class TCPStreamer {
  SendPort? _sendPort;
  Isolate? _isolate;

  Future<void> init() async {
    if (_sendPort != null) return;

    debugPrint("TCPStreamer: Attempting to spawn background isolate...");
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_tcpIsolate, {
      'port': receivePort.sendPort,
      'targetIP': hPi4Global.tcpTargetIP,
      'targetPort': hPi4Global.tcpTargetPort,
    });

    _sendPort = await receivePort.first as SendPort;
    debugPrint("TCPStreamer: Isolate spawned and communication established.");
  }

  void streamBatch(String type, List<dynamic> samples) {
    _sendPort?.send({'type': type, 'samples': samples});
  }

  void sendData(String message) {
    _sendPort?.send(message);
  }

  void close() {
    debugPrint("TCPStreamer: Closing streamer...");
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
      debugPrint("TCPStreamer Isolate: Attempting connection to $targetIP:$targetPort...");
      socket = await Socket.connect(targetIP, targetPort, timeout: const Duration(seconds: 5));
      debugPrint("TCPStreamer Isolate: Connection established successfully.");
    } on SocketException catch (e) {
      debugPrint("TCPStreamer Isolate: SocketException during connection: $e");
    } on Exception catch (e) {
      debugPrint("TCPStreamer Isolate: Unexpected error during connection: $e");
    }

    await for (final message in commandPort) {
      if (message == null) {
        debugPrint("TCPStreamer Isolate: Received close signal.");
        break;
      }
      if (socket == null) {
        // If socket is null, we can't send data.
        // We continue to drain the port in case it reconnects or closes.
        continue;
      }

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
          // debugPrint("TCPStreamer Isolate: Data sent successfully (${payload.length} chars)");
        } on SocketException catch (e) {
          debugPrint("TCPStreamer Isolate: SocketException during data send: $e");
          break; // Exit on socket error
        } catch (e) {
          debugPrint("TCPStreamer Isolate: Error sending TCP data: $e");
          break;
        }
      }
    }

    debugPrint("TCPStreamer Isolate: Cleaning up and closing socket.");
    await socket?.close();
    socket?.destroy();
  }
}

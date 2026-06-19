import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../globals.dart';

class TCPStreamer {
  SendPort? _sendPort;
  Isolate? _isolate;
  ReceivePort? _receivePort;

  Future<String?> init() async {
    if (_sendPort != null) return null;

    debugPrint("TCPStreamer: Initializing background isolate...");
    _receivePort = ReceivePort();

    try {
      _isolate = await Isolate.spawn(_tcpIsolate, {
        'port': _receivePort!.sendPort,
        'targetIP': hPi4Global.tcpTargetIP,
        'targetPort': hPi4Global.tcpTargetPort,
      });

      final Completer<String?> connectionCompleter = Completer<String?>();

      _receivePort!.listen((message) {
        if (message is SendPort) {
          _sendPort = message;
          debugPrint("TCPStreamer: Received SendPort from isolate.");
        } else if (message == "connected") {
          debugPrint("TCPStreamer: Isolate reported successful connection.");
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(null);
          }
        } else if (message is String && message.startsWith("connection_error:")) {
          final error = message.replaceFirst("connection_error:", "").trim();
          debugPrint("TCPStreamer: Isolate reported connection error: $error");
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(error);
          }
        } else if (message is String && message.startsWith("debug:")) {
          debugPrint("TCPStreamer Isolate Debug: ${message.replaceFirst("debug:", "")}");
        }
      });

      final result = await connectionCompleter.future.timeout(const Duration(seconds: 10), onTimeout: () {
        return "Connection timeout";
      });

      if (result != null) {
        close();
      }
      return result;
    } catch (e) {
      debugPrint("TCPStreamer: Error spawning isolate: $e");
      close();
      return e.toString();
    }
  }

  void streamBatch(String type, List samples) {
    if (_sendPort == null) {
      // Throttled log could go here
      return;
    }
    // Create a concrete list to avoid issues with TypedData views in Isolates
    _sendPort?.send({'type': type, 'samples': samples.toList()});
  }

  void sendData(String message) {
    _sendPort?.send(message);
  }

  void close() {
    debugPrint("TCPStreamer: Closing streamer...");
    _sendPort?.send(null); // Signal isolate to close
    // Give it a tiny bit of time to handle the close signal before killing
    Future.delayed(const Duration(milliseconds: 100), () {
      _isolate?.kill(priority: Isolate.immediate);
      _receivePort?.close();
      _isolate = null;
      _sendPort = null;
      _receivePort = null;
    });
  }

  static Future<bool> verifyConnection(String ip, int port) async {
    try {
      debugPrint("TCPStreamer: Verifying connection to $ip:$port...");
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 3));
      await socket.close();
      debugPrint("TCPStreamer: Verification successful.");
      return true;
    } catch (e) {
      debugPrint("TCPStreamer: Verification failed: $e");
      return false;
    }
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
      socket.setOption(SocketOption.tcpNoDelay, true);
      mainSendPort.send("connected");
    } catch (e) {
      mainSendPort.send("connection_error: $e");
      return;
    }

    await for (final message in commandPort) {
      if (message == null) break;
      if (socket == null) continue;

      String? payload;
      if (message is String) {
        payload = message;
      } else if (message is Map) {
        try {
          final String type = message['type'];
          final List samples = message['samples'];
          payload = samples.map((s) => "$type,$s").join("\n");
        } catch (e) {
          mainSendPort.send("debug: Error formatting batch: $e");
          continue;
        }
      }

      if (payload != null && payload.isNotEmpty) {
        try {
          socket.write("$payload\n");
          // Not awaiting flush to allow background Isolate to process messages faster,
          // OS will handle buffering.
        } catch (e) {
          mainSendPort.send("debug: Send error: $e");
          break;
        }
      }
    }

    await socket?.close();
    socket?.destroy();
  }
}

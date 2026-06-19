import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:OpenView2/utils/tcp_streamer.dart';
import 'package:OpenView2/globals.dart';

void main() {
  test('TCPStreamer connects and sends batched data correctly', () async {
    final streamer = TCPStreamer();

    // Set target to localhost for testing
    hPi4Global.tcpTargetIP = '127.0.0.1';
    hPi4Global.tcpTargetPort = 12350;

    // Create a server to verify the data
    ServerSocket server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 12350);

    List<String> receivedMessages = [];
    final completer = Completer<void>();

    server.listen((Socket client) {
      client.cast<List<int>>().transform(utf8.decoder).listen((message) {
        receivedMessages.add(message.trim());
        if (receivedMessages.length >= 2) {
          if (!completer.isCompleted) completer.complete();
        }
      });
    });

    final error = await streamer.init();
    expect(error, isNull, reason: "Streamer should initialize without error");

    streamer.sendData("SINGLE_DATA");
    streamer.streamBatch("BATCH", [1, 2, 3]);

    // Wait for the packets to be received with a timeout
    await completer.future.timeout(Duration(seconds: 2)).catchError((_) {});

    expect(receivedMessages, contains("SINGLE_DATA"));
    expect(receivedMessages, contains("BATCH,1\nBATCH,2\nBATCH,3"));

    streamer.close();
    await server.close();
  });

  test('TCPStreamer returns error on failed connection', () async {
    final streamer = TCPStreamer();

    hPi4Global.tcpTargetIP = '127.0.0.1';
    hPi4Global.tcpTargetPort = 9999;

    final error = await streamer.init();
    expect(error, isNotNull);

    streamer.close();
  });
}

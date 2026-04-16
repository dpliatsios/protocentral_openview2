import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:OpenView2/utils/tcp_streamer.dart';
import 'package:OpenView2/globals.dart';

void main() {
  test('TCPStreamer connects and sends data correctly', () async {
    final streamer = TCPStreamer();

    // Set target to localhost for testing
    hPi4Global.tcpTargetIP = '127.0.0.1';
    hPi4Global.tcpTargetPort = 12346; // Use a different port for TCP test

    // Create a server to verify the data
    ServerSocket server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 12346);

    bool received = false;
    server.listen((Socket client) {
      client.listen((List<int> data) {
        String message = String.fromCharCodes(data).trim();
        expect(message, "TEST_DATA,123");
        received = true;
      });
    });

    await streamer.init();
    streamer.sendData("TEST_DATA,123");

    // Give it a short moment to connect and receive
    await Future.delayed(Duration(milliseconds: 200));

    expect(received, isTrue);

    streamer.close();
    await server.close();
  });
}

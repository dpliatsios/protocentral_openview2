import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:OpenView2/utils/udp_streamer.dart';
import 'package:OpenView2/globals.dart';

void main() {
  test('UDPStreamer formats and sends data correctly', () async {
    final streamer = UDPStreamer();

    // Set target to localhost for testing
    hPi4Global.udpTargetIP = '127.0.0.1';
    hPi4Global.udpTargetPort = 12345;

    // Create a receiver socket to verify the data
    RawDatagramSocket receiver = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 12345);

    await streamer.init();
    streamer.sendData("TEST_DATA,123");

    // Wait for the packet to be received
    bool received = false;
    receiver.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? dg = receiver.receive();
        if (dg != null) {
          String message = String.fromCharCodes(dg.data);
          expect(message, "TEST_DATA,123");
          received = true;
        }
      }
    });

    // Give it a short moment to receive
    await Future.delayed(Duration(milliseconds: 100));

    expect(received, isTrue);

    streamer.close();
    receiver.close();
  });
}

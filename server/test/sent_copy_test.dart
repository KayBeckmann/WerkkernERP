import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:werkkernerp_server/src/mail.dart';

void main() {
  test(
    'APPEND waits for continuation and stores RFC5322 multipart with original content',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final seen = <String>[];
      final done = Completer<Uint8List>();
      server.listen((socket) async {
        final reader = _Reader(socket);
        try {
          socket.write('* OK ready\r\n');
          final login = await reader.line();
          seen.add(login);
          socket.write('A1 OK logged in\r\n');
          final append = await reader.line();
          seen.add(append);
          await socket.flush();
          // Literal must not be transmitted before the server continuation.
          expect(reader.buffered, isEmpty);
          socket.write('+ continue\r\n');
          final size = int.parse(
            RegExp(r'\{(\d+)\}$').firstMatch(append)!.group(1)!,
          );
          final mime = await reader.bytes(size);
          expect(await reader.bytes(2), [13, 10]);
          socket.write('A2 OK [APPENDUID 1 9] saved\r\n');
          seen.add(await reader.line());
          socket.write('A3 OK logout\r\n');
          done.complete(Uint8List.fromList(mime));
        } catch (e, st) {
          done.completeError(e, st);
        } finally {
          socket.destroy();
        }
      });
      try {
        final transport = ImapSentCopyTransport(
          connect: (host, port, timeout) =>
              Socket.connect(InternetAddress.loopbackIPv4, server.port),
        );
        await transport.save(
          const SentCopySettings(
            host: 'unused',
            port: 993,
            username: 'user',
            folder: 'Sent Items',
          ),
          'secret',
          OutgoingMail(
            to: 'to@example.org',
            subject: 'Rechnung ä',
            body: 'Grüße\nZeile 2',
            attachments: [
              MailAttachment(
                fileName: 'a.pdf',
                contentType: 'application/pdf',
                bytes: Uint8List.fromList([0, 1, 255]),
              ),
            ],
          ),
          fromAddress: 'from@example.org',
          fromName: 'Firma',
        );
        final mime = utf8.decode(await done.future);
        expect(seen[0], 'A1 LOGIN "user" "secret"');
        expect(seen[1], startsWith('A2 APPEND "Sent Items" (\\Seen) {'));
        expect(seen[2], 'A3 LOGOUT');
        expect(mime, contains('from: Firma <from@example.org>'));
        expect(mime, contains('to: to@example.org'));
        expect(mime, contains('application/pdf'));
        expect(mime, contains('a.pdf'));
        expect(
          mime,
          contains(
            'subject: =?utf-8?B?${base64.encode(utf8.encode('Rechnung ä'))}?=',
          ),
        );
        expect(mime, contains(base64.encode([0, 1, 255])));
        expect(
          mime,
          contains(base64.encode(utf8.encode('Grüße\r\nZeile 2\r\n'))),
        );
      } finally {
        await server.close();
      }
    },
  );
  test('APPEND rejection does not send the literal', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<List<int>>();
    server.listen((socket) async {
      final reader = _Reader(socket);
      socket.write('* OK ready\r\n');
      await reader.line();
      socket.write('A1 OK accepted\r\n');
      await reader.line();
      socket.write('A2 NO private mailbox diagnostic\r\n');
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      received.complete(reader.buffered);
      socket.destroy();
    });
    try {
      final transport = ImapSentCopyTransport(
        connect: (host, port, timeout) =>
            Socket.connect(InternetAddress.loopbackIPv4, server.port),
      );
      await expectLater(
        transport.save(
          const SentCopySettings(
            host: 'unused',
            port: 993,
            username: 'user',
            folder: 'Sent',
          ),
          'secret',
          const OutgoingMail(to: 'a@example.org', subject: 's', body: 'b'),
          fromAddress: 'b@example.org',
        ),
        throwsA(
          isA<SentCopyException>().having(
            (e) => e.toString(),
            'safe',
            isNot(contains('private')),
          ),
        ),
      );
      expect(await received.future, isEmpty);
    } finally {
      await server.close();
    }
  });

  test('MailService has a real IMAP Sent transport by default', () {
    final service = MailService(transport: RecordingMailTransport());
    expect(service.sentCopy, isA<ImapSentCopyTransport>());
  });
  test('MailService allows independent copy transport injection', () {
    final copy = RecordingSentCopyTransport();
    final service = MailService(
      transport: RecordingMailTransport(),
      sentCopy: copy,
    );
    expect(service.sentCopy, same(copy));
  });

  test(
    'server rejection does not disclose credentials or server response',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((socket) async {
        socket.write('* OK ready\r\n');
        final reader = _Reader(socket);
        await reader.line();
        socket.write('A1 NO password=topsecret user=private\r\n');
        await socket.flush();
        socket.destroy();
      });
      try {
        final transport = ImapSentCopyTransport(
          connect: (host, port, timeout) =>
              Socket.connect(InternetAddress.loopbackIPv4, server.port),
        );
        await expectLater(
          transport.save(
            const SentCopySettings(
              host: 'unused',
              port: 993,
              username: 'private',
              folder: 'Sent',
            ),
            'topsecret',
            const OutgoingMail(to: 'a@example.org', subject: 's', body: 'b'),
            fromAddress: 'b@example.org',
          ),
          throwsA(
            isA<SentCopyException>().having(
              (e) => e.toString(),
              'safe exception',
              allOf(isNot(contains('topsecret')), isNot(contains('private'))),
            ),
          ),
        );
      } finally {
        await server.close();
      }
    },
  );

  test('greeting timeout is bounded and sanitized', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {});
    try {
      final transport = ImapSentCopyTransport(
        timeout: const Duration(milliseconds: 100),
        connect: (host, port, timeout) =>
            Socket.connect(InternetAddress.loopbackIPv4, server.port),
      );
      await expectLater(
        transport.save(
          const SentCopySettings(
            host: 'unused',
            port: 993,
            username: 'user',
            folder: 'Sent',
          ),
          'secret',
          const OutgoingMail(to: 'a@example.org', subject: 's', body: 'b'),
          fromAddress: 'b@example.org',
        ),
        throwsA(isA<SentCopyException>()),
      );
    } finally {
      await server.close();
    }
  });

  test('invalid IMAP credentials are rejected before connection', () async {
    var connected = false;
    final transport = ImapSentCopyTransport(
      connect: (host, port, timeout) {
        connected = true;
        throw StateError('must not connect');
      },
    );
    await expectLater(
      transport.save(
        const SentCopySettings(
          host: 'unused',
          port: 993,
          username: 'user\r\nINJECT',
          folder: 'Sent',
        ),
        'secret',
        const OutgoingMail(to: 'a@example.org', subject: 's', body: 'b'),
        fromAddress: 'b@example.org',
      ),
      throwsA(isA<SentCopyException>()),
    );
    expect(connected, isFalse);
  });
}

class _Reader {
  _Reader(Socket socket) : _iterator = StreamIterator(socket);
  final StreamIterator<Uint8List> _iterator;
  final _buffer = <int>[];
  List<int> get buffered => List.of(_buffer);

  Future<List<int>> bytes(int count) async {
    while (_buffer.length < count) {
      if (!await _iterator.moveNext()) throw StateError('socket closed');
      _buffer.addAll(_iterator.current);
    }
    return _buffer.removeRangeCopy(count);
  }

  Future<String> line() async {
    while (true) {
      final end = _buffer.indexOf(10);
      if (end >= 0)
        return ascii.decode(_buffer.removeRangeCopy(end + 1)).trimRight();
      if (!await _iterator.moveNext()) throw StateError('socket closed');
      _buffer.addAll(_iterator.current);
    }
  }
}

extension on List<int> {
  List<int> removeRangeCopy(int count) {
    final result = sublist(0, count);
    removeRange(0, count);
    return result;
  }
}

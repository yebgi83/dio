import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:pedantic/pedantic.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const TEST_CONTENT_LENGTH = 5;
const SEND_DURATION_EACH_CHAR = 1000;

HttpServer? _server;

late Uri serverUrl;

Future<int> getUnusedPort() async {
  HttpServer? server;
  try {
    server = await HttpServer.bind('localhost', 0);
    return server.port;
  }  finally {
    unawaited(server?.close());
  }
}

void startServer(port) async {
  String makeContentByLength(length) {
    var result = '';

    for (var number = 1; number <= length; number++) {
      result += number.toString();
    }

    return result;
  }

  _server = await HttpServer.bind('localhost', port);
  _server?.listen((request) {
    var content = makeContentByLength(TEST_CONTENT_LENGTH);
    var response = request.response;

    response
      ..statusCode = 200
      ..contentLength = content.length;

    for (var charAt = 0; charAt < content.length; charAt++) {
      var oneChar = content[charAt];

      response.write(oneChar);
      sleep(const Duration(milliseconds: SEND_DURATION_EACH_CHAR));
    }

    response.close();
   });
}

void stopServer() {
  if (_server != null) {
    _server!.close();
    _server = null;
  }
}

void main() {
  const TEST_READ_TIMEOUT = TEST_CONTENT_LENGTH * SEND_DURATION_EACH_CHAR;

  setUp(() async {
    var port = await getUnusedPort();
    serverUrl = Uri.parse('http://localhost:$port');
    unawaited(Isolate.spawn(startServer, port));
  });

  tearDown(stopServer);

  test('#read_timeout - catch DioError when receiveTimeout < $TEST_READ_TIMEOUT(ms)', () async {
    var dio = Dio();

    dio.options
      ..baseUrl = serverUrl.toString()
      ..receiveTimeout = TEST_READ_TIMEOUT - 1000;

    DioError error;

    try {
      await dio.get('/');
      fail('did not throw');
    } on DioError catch (e) {
      error = e;
    }

    expect(error, isNotNull);
    expect(error.type == DioErrorType.receiveTimeout, isTrue);
  });

  test('#read_timeout - no DioError when receiveTimeout > $TEST_READ_TIMEOUT(ms)', () async {
    var dio = Dio();

    dio.options
      ..baseUrl = serverUrl.toString()
      ..receiveTimeout = TEST_READ_TIMEOUT + 1000;

    DioError ? error;

    try {
      await dio.get('/');
    } on DioError catch (e) {
      error = e;
    }

    expect(error, isNull);
  });
}
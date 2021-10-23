import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:pedantic/pedantic.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

const SERVER_WAIT_BEFORE_WRITE = 5000;

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
  _server = await HttpServer.bind('localhost', port);
  _server?.listen((request) {
    var content = 'success';
    var response = request.response;

    sleep(const Duration(milliseconds: SERVER_WAIT_BEFORE_WRITE));

    response
      ..statusCode = 200
      ..contentLength = content.length
      ..write(content);

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
  setUp(() async {
    var port = await getUnusedPort();
    serverUrl = Uri.parse('http://localhost:$port');
    unawaited(Isolate.spawn(startServer, port));
  });

  tearDown(stopServer);

  test('#connect_timeout - catch DioError when connectTimeout < $SERVER_WAIT_BEFORE_WRITE(ms)', () async {
      var dio = Dio();

      dio.options
        ..baseUrl = serverUrl.toString()
        ..connectTimeout = SERVER_WAIT_BEFORE_WRITE - 1000;

      DioError error;

      try {
        await dio.get('/');
        fail('did not throw');
      } on DioError catch (e) {
        error = e;
      }

      expect(error, isNotNull);
      expect(error.type == DioErrorType.connectTimeout, isTrue);
    });

  test('#connect_timeout - no DioError when connectTimeout > $SERVER_WAIT_BEFORE_WRITE(ms)', () async {
    var dio = Dio();

    dio.options
      ..baseUrl = serverUrl.toString()
      ..connectTimeout = SERVER_WAIT_BEFORE_WRITE + 1000;

    DioError ? error;

    try {
      await dio.get('/');
    } on DioError catch (e) {
      error = e;
    }

    expect(error, isNull);
  });
}
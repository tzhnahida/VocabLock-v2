import 'package:dio/dio.dart';

class ApiClient {
  final Dio dio;
  final String baseUrl;
  final String token;

  ApiClient({required this.baseUrl, required this.token})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 30),
        ));

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path, {dynamic data}) => dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) => dio.put(path, data: data);

  Future<Response> delete(String path) => dio.delete(path);
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum ApiRequestType { get, post, put }

enum ApiResponseStatus { success, failed }

class ApiEngine {
  static const String commonExceptionMessage =
      'Something went wrong. Please try again later.';
  static const String connectivityExceptionMessage =
      'Please check your internet connectivity and try again.';

  static final ApiEngine _singleton = ApiEngine._internal();

  factory ApiEngine() => _singleton;

  ApiEngine._internal();

  final _jsonDecoder = const JsonDecoder();
  final _jsonEncoder = const JsonEncoder();

  Future<ApiResponse> performRequest(ApiRequestType requestType, String url,
      {dynamic payload,
      bool showIndicator = true,
      bool isWithToken = true}) async {
    bool isNetworkAvailable = await this.isNetworkAvailable();

    if (!isNetworkAvailable) {
      debugPrint('No internet connection');
      assert(
          isNetworkAvailable == true, ApiEngine.connectivityExceptionMessage);
    }

    assert(url.isNotEmpty, 'URL must not be empty or null');

    if (requestType == ApiRequestType.post ||
        requestType == ApiRequestType.put) {
      assert(payload != null, 'For POST request, you must send a payload.');
    }

    var headers = await _prepareHeaders(isWithToken);

    debugPrint('Api URL-----$url');
    debugPrint('Api Headers-----$headers');

    if (requestType == ApiRequestType.post ||
        requestType == ApiRequestType.put) {
      if (payload != null) debugPrint('Api Params-----$payload');
    }

    try {
      var actualURL = Uri.parse(url);
      switch (requestType) {
        case ApiRequestType.get:
          http.Response response = await http.get(actualURL, headers: headers);
          return handleHTTPResponse(response);
        case ApiRequestType.post:
          http.Response response;
          if (payload != null) {
            String body = _jsonEncoder.convert(payload);
            response = await http.post(actualURL, headers: headers, body: body);
          } else {
            response = await http.post(actualURL, headers: headers);
          }
          return handleHTTPResponse(response);
        case ApiRequestType.put:
          http.Response response;
          if (payload != null) {
            String body = _jsonEncoder.convert(payload);
            response = await http.put(actualURL, headers: headers, body: body);
          } else {
            response = await http.put(actualURL, headers: headers);
          }
          return handleHTTPResponse(response);
      }
    } catch (exception) {
      return commonExceptionResponse();
    }
  }

  ApiResponse handleHTTPResponse(http.Response response) {
    debugPrint('Api Status Code-----${response.statusCode}');
    debugPrint('Api Response-----${response.body}');

    switch (response.statusCode) {
      case 200:
      case 201:
        var status = ApiResponseStatus.success;
        var data = _jsonDecoder.convert(response.body);
        var apiResponse = ApiResponse(status, data);
        return apiResponse;
      default:
        var status = ApiResponseStatus.failed;
        var data = _jsonDecoder.convert(response.body);
        var exception =
            Exception(data['message'] ?? ApiEngine.commonExceptionMessage);
        var apiResponse = ApiResponse(status, data, exception: exception);
        return apiResponse;
    }
  }

  ApiResponse commonExceptionResponse() {
    var status = ApiResponseStatus.failed;
    var exception = Exception(ApiEngine.commonExceptionMessage);
    var apiResponse = ApiResponse(status, null, exception: exception);
    return apiResponse;
  }

  Future<Map<String, String>> _prepareHeaders(bool isWithToken) async {
    var headers = {
      'Content-type': 'application/json',
      'Accept': 'application/json'
    };
    if (isWithToken) {
      headers['Authorization'] = 'Bearer ';
    }

    return headers;
  }

  Future<bool> isNetworkAvailable() async {
    bool isAvailable = false;
    try {
      final result = await InternetAddress.lookup('example.com');
      isAvailable = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      isAvailable = false;
    }
    return isAvailable;
  }
}

class ApiResponse {
  ApiResponseStatus status;
  Exception? exception;
  String message;
  dynamic data;

  ApiResponse(this.status, this.data, {this.exception, this.message = ''});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> jsonData = <String, dynamic>{};

    jsonData['Response_Status'] =
        status == ApiResponseStatus.success ? 'SUCCESS' : 'FAILED';
    jsonData['Response_Data'] = data;

    if (exception != null) {
      jsonData['Response_Exception'] = exception.toString();
    }
    if (message.isNotEmpty) {
      jsonData['Response_Message'] = message;
    }

    return jsonData;
  }
}

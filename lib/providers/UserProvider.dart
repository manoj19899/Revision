import 'dart:convert';

import 'package:api_cache_manager/models/cache_db_model.dart';
import 'package:api_cache_manager/utils/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:revision/models/AssociateModel.dart';
import 'package:revision/providers/AuthProvider.dart';

import '../constants/app.dart';
import '../functions.dart';
import 'package:http/http.dart' as http;

class UserProvider extends ChangeNotifier {
  late AssociateModel associate;
  XFile? imageFile;
  bool uploadingImage = false;
  List recommendedBio = [];
  TextEditingController lastNameController = TextEditingController();
  double totalDirect = 0.0;
  double totalReferral = 0.0;
  double totalWallet = 0.0;
  List<GraphData> diGraphData = [];
  List<GraphData> refGraphData = [];

  initRecommendedBio() async {
    if (associate.data != null) {
      recommendedBio.clear();
      lastNameController.clear();
      recommendedBio
          .add(TextEditingController(text: associate.data!.firstName ?? ''));
      recommendedBio
          .add(TextEditingController(text: associate.data!.email ?? ''));
      recommendedBio
          .add(TextEditingController(text: associate.data!.phone ?? ''));
      recommendedBio
          .add(TextEditingController(text: associate.data!.address ?? ''));
      lastNameController.text = associate.data!.lastName ?? '';
      notifyListeners();
    }
  }

  Future<void> updateImage() async {
    try {
      if (isOnline) {
        var url = App.baseUrl + App.updateProfileImage;
        var headers = {
          'Accept': '*/*',
          'Authorization': 'Bearer ${associate.token}'
        };
        var request = http.MultipartRequest(
          'POST',
          Uri.parse(url),
        );
        uploadingImage = true;
        notifyListeners();
        request.files.add(await http.MultipartFile.fromPath(
            'profile_image', imageFile!.path));
        request.headers.addAll(headers);
        var res = await request.send();
        // print('res ------> $res');
        var responseData = await res.stream.toBytes();

        var result = String.fromCharCodes(responseData);

        if (res.statusCode == 200) {
          if (jsonDecode(result)['status'] == 200) {
            Provider.of<AuthProvider>(Get.context!, listen: false)
                .username
                .text = prefs.getString('username')!;
            Provider.of<AuthProvider>(Get.context!, listen: false)
                .passController
                .text = prefs.getString('password')!;
            await Provider.of<AuthProvider>(Get.context!, listen: false)
                .login();
          }
          Fluttertoast.showToast(msg: jsonDecode(result)['message']);
        }

        uploadingImage = false;
        notifyListeners();
      } else {
        showNetWorkToast(msg: 'You are offline. Please connect to network');
      }
    } catch (e) {
      print('e e e e e e e   e  ee e  e ---> $e');
    }

    uploadingImage = false;
    notifyListeners();
  }

  Future<void> updateProfile() async {
    try {
      hoverLoadingDialog(true);
      if (isOnline) {
        var url = App.baseUrl + App.updateProfileInfo;
        var headers = {
          'Accept': '*/*',
          'Authorization': 'Bearer ${associate.token}'
        };
        var body = {
          "user_id": associate.data!.id.toString(),
          "email": recommendedBio[1].text,
          "first_name": recommendedBio[0].text,
          "last_name": lastNameController.text,
          "phone": recommendedBio[2].text,
          "address": recommendedBio[3].text
        };
        var res = await http.post(Uri.parse(url), headers: headers, body: body);
        if (res.statusCode == 200) {
          if (jsonDecode(res.body)['success'] == 200) {
            await initiateUserOffline();
          }
          Fluttertoast.showToast(msg: jsonDecode(res.body)['message']);
        }
      } else {
        showNetWorkToast(msg: 'You are offline. Please connect to network');
      }
    } catch (e) {
      print('e e e e e e e   e  ee e  e ---> $e');
    }
    hoverLoadingDialog(false);
  }

  Future<void> getDashboard() async {
    var response;

    try {
      await checkVersion();

      bool cacheExist = await APICacheManager().isAPICacheKeyExist('dashboard');
      if (isOnline) {
        var url = '${App.baseUrl}${App.dashboard}';
        var headers = {
          'Accept': '*/*',
          'Authorization': 'Bearer ${prefs.getString('token')!}'
        };
        var res = await http.get(Uri.parse(url), headers: headers);
        debugPrint('dash board data ${res.body}');

        if (res.statusCode == 200) {
          if (jsonDecode(res.body)['success'] == 200) {
            var data = jsonDecode(res.body)['data'];
            var cacheModel =
                APICacheDBModel(key: 'dashboard', syncData: jsonEncode(data));
            await APICacheManager().addCacheData(cacheModel);
            response = cacheModel.syncData;
          } else {
            Fluttertoast.showToast(msg: jsonDecode(res.body)['message']);
          }
        }
        print("it's url Hit ");
      } else {
        showNetWorkToast();
        if (cacheExist) {
          response =
              (await APICacheManager().getCacheData('dashboard')).syncData;
          print("it's cache Hit $response");
        }
      }
      response = jsonDecode(response);
      if (response != null) {
        print('response type is ${response.runtimeType}');

        totalDirect = double.parse(response['direct_income'].toString());
        totalReferral = double.parse(response['referral_income'].toString());
        totalWallet = double.parse(response['walletBalance'].toString());
        diGraphData.clear();
        refGraphData.clear();
        response['directIncome_graph'].forEach((e) {
          print(e);
          diGraphData.add(GraphData.fromJson(e));
        });
        response['referral_income_graph'].forEach((e) {
          print(e);
          refGraphData.add(GraphData.fromJson(e));
        });
        notifyListeners();
        debugPrint(
            'dash board data digraph ${diGraphData.length}  refgraph ${refGraphData.length}-> ');
      }
    } catch (e) {
      debugPrint('e e e e e dash board data  e e -> $e');
    }
  }
}

class GraphData {
  double? total;
  String? month;

  GraphData({this.total, this.month});

  GraphData.fromJson(Map<String, dynamic> json) {
    month = json['month'];
    total = double.parse(json['total'] ?? '0');
  }

  Map<String, dynamic> toJson() {
    print(json);
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total'] = total;
    data['month'] = month;
    return data;
  }
}

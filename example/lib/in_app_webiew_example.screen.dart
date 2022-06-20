import 'dart:collection';
import 'dart:convert';
// import 'dart:convert';
import 'dart:io';
// import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';

class InAppWebViewExampleScreen extends StatefulWidget {
  @override
  _InAppWebViewExampleScreenState createState() =>
      new _InAppWebViewExampleScreenState();
}

class _InAppWebViewExampleScreenState extends State<InAppWebViewExampleScreen> {

  final GlobalKey webViewKey = GlobalKey();

  final String messageMsg =  """window.addEventListener('message', function( message ){
    let action = JSON.parse(message.data);
    console.log("返回首页地址", action.value);
    
    if(action.Name == "goBackHome"){
      location.href = action.url;
    }
  })""";
  final String messageMsg2 =  """window.addEventListener("message",function(msg){
	try{
		console.log(">>>>>>msg",msg);
		var t=JSON.parse(msg.data);
		if(console.log(">>>>data",t),t.method)
		switch(t.method){
		}
	}catch(e){
		console.log(">>>报错", e)
	}
})""";

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        /// 打开这个，才能接收到回调
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        transparentBackground: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      android: AndroidInAppWebViewOptions(
        /// 打开这个则不能使用，Offstage
        useHybridComposition: true,
        blockNetworkImage: false,
        mixedContentMode:
        AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,

        allowFileAccess: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  late PullToRefreshController pullToRefreshController;
  late ContextMenu contextMenu;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    contextMenu = ContextMenu(
        menuItems: [
          ContextMenuItem(
              androidId: 1,
              iosId: "1",
              title: "Special",
              action: () async {
                print("Menu item Special clicked!");
                print(await webViewController?.getSelectedText());
                await webViewController?.clearFocus();
              })
        ],
        options: ContextMenuOptions(hideDefaultSystemContextMenuItems: false),
        onCreateContextMenu: (hitTestResult) async {
          print("onCreateContextMenu");
          print(hitTestResult.extra);
          print(await webViewController?.getSelectedText());
        },
        onHideContextMenu: () {
          print("onHideContextMenu");
        },
        onContextMenuActionItemClicked: (contextMenuItemClicked) async {
          var id = (Platform.isAndroid)
              ? contextMenuItemClicked.androidId
              : contextMenuItemClicked.iosId;
          print("onContextMenuActionItemClicked: " +
              id.toString() +
              " " +
              contextMenuItemClicked.title);
        });

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("InAppWebView")),
        drawer: myDrawer(context: context),
        body: SafeArea(
            child: Column(children: <Widget>[
          TextField(
            decoration: InputDecoration(
                prefixIcon: Icon(Icons.search)
            ),
            controller: urlController,
            keyboardType: TextInputType.url,
            onSubmitted: (value) {
              var url = Uri.parse(value);
              if (url.scheme.isEmpty) {
                url = Uri.parse("https://www.google.com/search?q=" + value);
              }
              webViewController?.loadUrl(
                  urlRequest: URLRequest(url: url));
            },
          ),
          Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    key: webViewKey,
                    // contextMenu: contextMenu,
                    // initialUrlRequest:
                    // URLRequest(url: Uri.parse("https://github.com/flutter")),

                    initialFile: "assets/index.html",
                    initialUserScripts: UnmodifiableListView<UserScript>([]),
                    initialOptions: options,
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      // controller.evaluateJavascript(source: messageMsg);
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    androidOnPermissionRequest: (controller, origin, resources) async {
                      return PermissionRequestResponse(
                          resources: resources,
                          action: PermissionRequestResponseAction.GRANT);
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      var uri = navigationAction.request.url!;

                      if (![
                        "http",
                        "https",
                        "file",
                        "chrome",
                        "data",
                        "javascript",
                        "about"
                      ].contains(uri.scheme)) {
                        if (await canLaunch(url)) {
                          // Launch the App
                          await launch(
                            url,
                          );
                          // and cancel the request
                          return NavigationActionPolicy.CANCEL;
                        }
                      }

                      return NavigationActionPolicy.ALLOW;
                    },
                  androidOnFilePermissionRequest: (
                      InAppWebViewController controller,
                      List<String> needPermissions) async {
                      print("Flutter接收到android返回的数据，需要权限 $needPermissions");

                  },
                    onLoadStop: (controller, url) async {
                      pullToRefreshController.endRefreshing();
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                      /// ceshi
                      await controller.evaluateJavascript(source: messageMsg);
                    },
                    onLoadError: (controller, url, code, message) {
                      pullToRefreshController.endRefreshing();
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress == 100) {
                        pullToRefreshController.endRefreshing();
                      }
                      setState(() {
                        this.progress = progress / 100;
                        urlController.text = this.url;
                      });
                    },
                    onUpdateVisitedHistory: (controller, url, androidIsReload) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      print(consoleMessage);
                    },
                  ),
                  progress < 1.0
                      ? LinearProgressIndicator(value: progress)
                      : Container(),
                ],
              ),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                child: Icon(Icons.arrow_back),
                onPressed: () {
                  webViewController?.goBack();
                },
              ),
              ElevatedButton(
                child: Icon(Icons.arrow_forward),
                onPressed: () async{
                  // webViewController?.goForward();
                  Map params = {
                    "method": "asd",
                    "value": "123456",
                  };
                  if(await AndroidWebViewFeature.isFeatureSupported(AndroidWebViewFeature.fromValue("POST_WEB_MESSAGE")!)){
                    print("zzb我支持这个功能");
                  }else {
                    print("zzb我走到这里");
                  }
                  webViewController?.postWebMessage(message: WebMessage(data: json.encode(params)));
                },
              ),
              ElevatedButton(
                child: Icon(Icons.refresh),
                onPressed: () {
                  webViewController?.reload();
                },
              ),
            ],
          ),
        ])));
  }
}

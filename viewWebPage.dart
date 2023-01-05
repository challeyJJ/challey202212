import 'package:challeybiz/utils/utilities.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ViewWebPage extends StatefulWidget {
  const ViewWebPage({Key? key, required this.url}) : super(key: key);
  final String url;

  @override
  State<ViewWebPage> createState() => _ViewWebPageState(url:this.url);
}

class _ViewWebPageState extends State<ViewWebPage> {
  _ViewWebPageState({required this.url});
  final String url;
  var loadingPercentage = 0;
  final GlobalKey<ScaffoldState> _key = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    print(url);
    return Scaffold(
        key: _key,
        appBar: getAppBar(context, '공지사항', '공지사항', _key),
        endDrawer: getChalleyDrawer(context),
        body: Stack(
          children: [
            WebView(
              initialUrl: url,
              javascriptMode: JavascriptMode.unrestricted,
              onPageStarted: (url) {
                setState(() {
                  loadingPercentage = 0;
                });
              },
              onProgress: (progress) {
                setState(() {
                  loadingPercentage = progress;
                });
              },
              onPageFinished: (url) {
                setState(() {
                  loadingPercentage = 100;
                });
              },
            ),
            if (loadingPercentage < 100)
              LinearProgressIndicator( value: loadingPercentage / 100.0,),
          ],
        ),
    );
  }
}

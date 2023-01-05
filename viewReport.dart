import 'package:cached_network_image/cached_network_image.dart';
import 'package:challeybiz/page/reportsPage.dart';
import 'package:challeybiz/utils/network.dart';
import 'package:flutter/material.dart';
import 'package:challeybiz/globals.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:challeybiz/model/storage.dart';
import 'package:http/http.dart' as http;
import 'package:challeybiz/utils/utilities.dart';
import 'package:challeybiz/utils/myLocation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ViewReportPage extends StatefulWidget {
  final Report report;
  const ViewReportPage({Key? key, required this.report}) : super(key: key);

  @override
  State<ViewReportPage> createState() => _ViewReportPageState(report: this.report);
}

class _ViewReportPageState extends State<ViewReportPage> {
  late ChalleyItem challey;       // 요게 표시할 챌리 아이템, 제목을 얻기 위해 init에서 해줌
  final Report report;            // 표시할 리포트
  _ViewReportPageState({required this.report});

  final GlobalKey<ScaffoldState> _key = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  final memoController = TextEditingController();

  //List<File> _images = List<File>.filled(10, File('') );  // 이미지 배열 초기회, 이미지는 총 10개를 넘지 않음

  @override
  void initState() {
    super.initState();
    challey = challeyInfo!.getChalleyItemByCid(report.cid);
    memoController.text = report.myMemo!;
  }

  //========================= 미션 하나하나를 넣는 콘테이너임 =======================
  Widget reportDataContainer() {
    List<Widget> formList = [];
    var reportJson = report.jsonList;
    String missionLabel = '';
    String picOX = '';
    String baseUrl = '';
    String url = '';
    String timePlace = '';
    String imgLabel = getReportImgTitle(report);
    for(int i=0; i<reportJson.length; i++) {
      missionLabel = report.jsonChalley[i]['label'];
      formList.add(
        Align(
          alignment: Alignment.topLeft,
          child: Text( "  " + missionLabel, textAlign: TextAlign.start,
            style: const TextStyle( fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xff3e3e3f) ),
          ),
        ),
      );
      formList.add(const SizedBox(height: 8,));

      if (report.jsonChalley[i]['type']=='image') {
        List<String> imgTitles =  report.jsonChalley[i]['data'].split('|');
        List<Widget> imgBtnList =  [];
        picOX = report.jsonList[ missionLabel ];
        timePlace = report.wtime! + "\n" + report.addr!;
        baseUrl = "http://${userInfo!.picServer}/uploads/${userInfo!.cToken}/report/${report.cid}/${userInfo!.userId}_${report.id}_";
        for(int i2=0; i2<imgTitles.length; i2++) {
          url = "$baseUrl$i2";
          imgBtnList.add(
            Container(
              decoration: BoxDecoration( color: Color(0xffb3dcc0), borderRadius: BorderRadius.circular(10) ),
              padding: picOX[i2] == 'O' ? EdgeInsets.zero : const EdgeInsets.only(top:50),
              child: picOX[i2] == 'O'
                ? GestureDetector(
                    onTap: () {
                      int index=i2;
                      print ("*******>>>> $url   $i2");
                      Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenPage(url: "$baseUrl$index", timePlace: timePlace,)), );
                    },
                    child: CachedNetworkImage(
                      imageUrl: url,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Image.asset('images/profile.jpg',fit: BoxFit.cover,width: 80,height: 80,),
                      cacheManager: CacheManager( Config("reportImages", stalePeriod: const Duration(days: 7),) ),
                    )
                  )
                : Column(
                  children: [
                    Text(imgTitles[i2], style: const TextStyle( fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xff3e3e3f) ),),
                    const SizedBox(height:20),
                    Icon(Icons.camera_alt, size: 50.0, color: Colors.grey[800],),
                  ]
              ),
            ),
          );
        }
        formList.add(
            GridView.count(
              crossAxisCount: 2, //1 개의 행에 2 item
              childAspectRatio: 3 / 4, // (480:640의 비율)
              mainAxisSpacing: 10, //수평 Padding
              crossAxisSpacing: 10, //수직 Padding
              shrinkWrap: true,
              children: imgBtnList,
            ),
        );
      }
      else { // 이미지 아닌 경우. 텍스트 등등
        formList.add(
          Container(
            padding: const EdgeInsets.fromLTRB(30, 15, 35, 15),
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xffdcdddf),
              borderRadius: BorderRadius.all(Radius.circular(5.0)),
            ),
            // child: Text( reportJson[ missionLabel ],
            child: Text( (report.jsonChalley[i]['type']!='select')
              ? reportJson[ missionLabel ] : getReportSelectedString(report, missionLabel,  int.parse(reportJson[missionLabel]) ),
               style: const TextStyle( fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xff3e3e3f) ),
            ),
          ),
        );
      }
      formList.add( const SizedBox(height:20.0) );
    }

    return Container(
      color: const Color(0xffffffff),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: formList,
        ),
    );
  }

  //================= 유틸 함수들 : 토큰 워터마킹, GPS, 과 이미지 업로드 ==================================


  //==========================================================================
  @override
  Widget build(BuildContext context) {
    String statusStr ='관리자 확인 대기중';
    String defaultMgrMemo = '수고하셨습니다. 관리자 코멘트는 없습니다';
    Color statColor = const Color(0xff4c5387);
    if (report.status == 'A') {
      statusStr = (report.utime==report.wtime) ? "제출결과: 자동승인" : "관리자 확인: 승인 (${report.utime})";
    }
    else if (report.status == 'D') { statusStr = "관리자 확인: 보류 (${report.utime})"; statColor = Colors.redAccent; }
    if ( (report.managerMemo!=null) && (report.managerMemo!='') ) {
      defaultMgrMemo = report.managerMemo!;
    }

    return Scaffold(
      key: _key,
      appBar: getAppBar(context, 'submit', '업무 보고', _key),
      endDrawer: getChalleyDrawer(context),
      body: SingleChildScrollView(
        //color: Color(0xfff6f6f6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height:30,),
                  Text( "[${challey.title!}]", style: const TextStyle( fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xff3e3e3f) ), ),
                  const SizedBox(height:20.0),
                  Text( '제출일시: ' + report.wtime!, style: const TextStyle( fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xff3e3e3f) ), ),
                  const SizedBox(height:10.0),
                  Text( '제출장소: ' + report.addr!, style: const TextStyle( fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xff3e3e3f) ), ),
                  const SizedBox(height:10.0),
                  Text( statusStr, style: TextStyle( fontSize: 15, fontWeight: FontWeight.w400, color: statColor ), ),
                  const SizedBox(height:10.0),
                  (report.managerMemo!='') ? Container(
                    padding: const EdgeInsets.fromLTRB(30, 15, 35, 15),
                    decoration: const BoxDecoration(
                      color: Color(0xfffceff6),
                      borderRadius: BorderRadius.all(Radius.circular(15.0)),
                    ),
                    child: Text(defaultMgrMemo,
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff3b67ae)),
                    ),
                  ) : const Divider(color: Colors.grey, height: 2, thickness: 2, ),
                  const SizedBox(height: 30),
                ],
              ),
              reportDataContainer(),

              const SizedBox(height:10.0),
              (report.status == 'W') ?
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children : [
                      const Divider(height: 1, thickness: 1, color: Color(0xff3b5998)),
                      const SizedBox(height:20.0),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text('※ 수고하셨습니다. 업무 보고가 잘 저장되었습니다. 혹시 추가로 관리자에게 하실 말씀이 있거나, 기존 보고를 취소하실 경우에는 아래 메모란을 활용하시면 됩니다.',
                          style: TextStyle( fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xff54595F) ), ),
                      ),
                      const SizedBox(height:10.0),
                      TextFormField(

                        validator: (val) {
                          if ( (val==null || val.isEmpty) ) { return "취소사유나 추가할 메모를 기재해주세요"; }
                          return null;
                        },
                        autovalidateMode: AutovalidateMode.disabled,
                        controller: memoController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(15.0)),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.fromLTRB(30, 15, 35, 15),
                          filled: true,
                          hintStyle: TextStyle( fontWeight: FontWeight.w500, fontSize: 15, color: Color(0xff873c64),  ),
                          //hintText: '추가할 메모가 있으면 기록해주세요. 취소할 경우에는 취소 사유를 기재해주세요',
                          fillColor: Color(0xfffceff6),
                        ),
                        minLines: 3,
                        maxLines: 30,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height:30.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('추가 메모가 저장되었습니다')),
                                  );
                                  challeySession.addMemoReport(report.id, memoController.text);
                                  report.myMemo = memoController.text;
                                  Navigator.pop(context);
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => ViewReportPage(report: report,)), );
                                }
                              },
                              style: TextButton.styleFrom(
                                fixedSize: const Size.fromHeight(50),
                                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                                backgroundColor: const Color(0xff2f67ac),
                                primary: const Color(0xffedf1f7),
                                textStyle: const TextStyle( fontSize: 18, fontWeight: FontWeight.w500 ),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
                              ),
                              child: const Text('메모 저장'),
                            ),
                            const SizedBox(width: 10,),
                            TextButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('제출한 보고서를 취소합니다')),
                                  );
                                  challeySession.cancelReport(report.id, memoController.text);
                                  Navigator.pop(context);
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsPage(cid: 0)), );
                                }
                                print("보고취소");
                              },
                              style: TextButton.styleFrom(
                                fixedSize: const Size.fromHeight(50),
                                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                                backgroundColor: const Color(0xff2f67ac),
                                primary: const Color(0xffedf1f7),
                                textStyle: const TextStyle( fontSize: 18, fontWeight: FontWeight.w500 ),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
                              ),
                              child: const Text('보고 취소'),
                            ),
                          ],
                        ),
                      const SizedBox(height:30.0) ,
                    ],
                  ),
                )
              :
              (challey.type != 'A') ?
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('나의 추가 메모 ', style: TextStyle( fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xff54595F) ), ),
                  const SizedBox(height:10.0),
                  Container(
                    padding: const EdgeInsets.fromLTRB(30, 15, 35, 15),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xffb3dcc0),
                      borderRadius: BorderRadius.all(Radius.circular(5.0)),
                    ),
                    // child: Text( reportJson[ missionLabel ],
                    child: Text( ( (report.myMemo==null)||(report.myMemo=="") ) ? "메모를 추가하지 않았습니다" + challey.type! : "${report.myMemo!} (${report.utime})",
                      style: const TextStyle( fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xff3b67ae) ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ) : const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

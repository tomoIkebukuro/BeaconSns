




import 'api.dart';
import 'class.dart';

import 'dart:io';
import 'package:meta/meta.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:rxdart/rxdart.dart';
import 'package:provider/provider.dart';
import 'dart:developer';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:progress_dialog/progress_dialog.dart';
import 'package:flutter/services.dart' show rootBundle;



const double ACTIONS_ICON_SIZE=20.0;

void main() {

  //Apiには複数のページで共有する情報や関数が入っている
  //そのためここでProviderを使って子クラスに渡していく
  runApp(
    Provider<Api>(
      create:(context)=> Api(),
      dispose:(context,model)=> model.dispose(),
      child:ChangeNotifierProvider<BookmarkModel>(
        create:(context)=>BookmarkModel(api: Provider.of<Api>(context,listen:false)),
        child: MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (context) => LoadUserPage()
          },
          theme: ThemeData(
              primarySwatch: Colors.deepOrange,
              accentColor: Colors.deepOrangeAccent
          ),
        ),
      ),
    ),
  );
}

//ユーザー情報を取得する
class LoadUserPage extends StatelessWidget{

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<bool>(
        future: Provider.of<Api>(context).initUser(),
        builder:(context,snapshot){

          //github issuesよりsnapshot.hasDataは信用できないみたいなのでこれ以後使用禁止
          //https://github.com/flutter/flutter/issues/22199
          if(snapshot.hasError||snapshot.connectionState==ConnectionState.none){
            return ErrorOccurredPage(widgetName: 'LoadUserPage',);
          }
          if(snapshot.connectionState==ConnectionState.waiting){
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          if(snapshot.data){
            return LoadProfilePage();
          }
          else{
            return SignInPage();
          }
        }
    );
  }
}

class SignInPage extends StatelessWidget{

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FlutterLogo(
              size: 150.0,
            ),
            SignInButton(
              Buttons.Google,
              text: "Google",
              onPressed: () async {
                if(await Provider.of<Api>(context).signInGoogle()){
                  Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (context) => LoadUserPage()
                  ));
                }
                else{
                  showDialog(
                    context: context,
                    builder: (_) {
                      return AlertDialog(
                        title: Text("エラー"),
                        content: Text("アカウントを認証できませんでした。"),
                        actions: <Widget>[
                          FlatButton(
                            child: Text("OK"),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
            )
          ],
        ),
      ),
    );
  }
}

class LoadProfilePage extends StatelessWidget{

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<bool>(
      future: Provider.of<Api>(context).initMyProfile(),
      builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.none||snapshot.hasError){
          return ErrorOccurredPage(widgetName: 'LoadProfilePage',);
        }
        else if(snapshot.connectionState==ConnectionState.waiting){
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        else{
          if(snapshot.data){
            return MainPage();
          }
          else{

            //ボタンが押されてからWidgetを作ると時間がかかる。
            //そのためあらかじめ作っておく
            Widget editProfilePage=EditProfilePage();

            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 150.0,
                      height: 150.0,
                      child: FlutterLogo(),
                    ),
                    Text(
                      'ダウンロードいただきありがとうございます!',
                      style: TextStyle(fontSize: 15.0),
                    ),
                    Text(
                      'プロフィールの設定を行います。',
                      style: TextStyle(fontSize: 15.0),
                    ),
                    SizedBox(
                      height: 25.0,
                      width: 100.0,
                      child: FlatButton(
                        color: Colors.deepOrange,
                        textColor: Colors.white,
                        child: Text('次に進む'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => editProfilePage),
                          );
                        },
                      ),
                    )
                  ],
                ),
              ),
            );
          }
        }
      },
    );
  }
}



class NetworkImageModified extends StatelessWidget{

  final String url;

  NetworkImageModified(this.url);

  Future<bool> cacheImage(String url,BuildContext context) async {
    if(url==null){
      return false;
    }
    bool hasNoError=true;
    await precacheImage(
        NetworkImage(url),
        context,
        onError: (e,stackTrace)=>hasNoError=false,
    );
    return hasNoError;
  }

  @override
  Widget build(context){

    return FutureBuilder(
      future:cacheImage(url, context),
      builder: (context,snapshot){
        if(snapshot.connectionState==ConnectionState.none||snapshot.hasError){
          return Container(
            height: 80.0,
            decoration: BoxDecoration(
                color: Colors.grey
            ),
            child: Center(
              child: Text('Error',),
            ),
          );
        }
        if(snapshot.connectionState==ConnectionState.waiting){
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey
            ),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        if(snapshot.data==false){
          return Container(
            height: 80.0,
            decoration: BoxDecoration(
                color: Colors.grey
            ),
            child: Center(
              child: Text('Error',style: TextStyle(fontSize: 10.0),),
            ),
          );
        }
        return Image.network(url);
      },
    );
  }
}

class ReplyTile extends StatelessWidget{

  final Beacon reply;
  final Beacon beacon;
  final Function onRemovePressed;

  ReplyTile({@required this.reply,@required this.beacon,@required this.onRemovePressed});

  @override
  Widget build(context){

    Api api=Provider.of<Api>(context);
    var myProfile=api.myProfileSubject.value;

    if(myProfile==null||reply==null||beacon==null){
      return Container(
        decoration: BoxDecoration(
          border: Border.all(width:0.0),
        ),
        child: ListTile(
          subtitle: Text('コメントが存在しません。\n削除された可能性があります。'),
        ),
      );
    }
    bool couldRemove=(myProfile.id==reply.profile.id)||(myProfile.id==beacon.profile?.id);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(width: 0.0),
      ),
      child: ListTile(
        leading: GestureDetector(
          child: Container(
            height: 40.0,
            width: 40.0,
            //IconButtonを使うと余白がおかしい
            //Material designの仕様
            //https://stackoverflow.com/questions/50381157/how-do-i-remove-flutter-iconbutton-big-padding
            child: ClipOval(
              child: NetworkImageModified(reply.profile?.avatarUrl),
            ),
          ),
          onTap: (){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage(profile: reply.profile,)),
            );
          },
        ),
        title: Text(reply?.profile?.id??''),
        subtitle: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.topLeft,
              child: Text(reply?.text),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                IconButton(
                  iconSize: ACTIONS_ICON_SIZE,
                  icon:Icon(
                    Icons.remove_circle_outline,
                    color: Colors.grey[couldRemove?600:300],
                  ),
                  onPressed: couldRemove?(){
                    onRemovePressed();
                    //api.removeReply(beaconId:beacon.id,replyId:reply.id);
                  }:null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BeaconTile extends StatelessWidget{

  final Beacon beacon;

  BeaconTile({this.beacon});

  @override
  Widget build(context){

    Api api=Provider.of<Api>(context);
    var myProfile=api.myProfileSubject.value;

    if(myProfile==null||beacon==null){
      return Container(
        decoration: BoxDecoration(
          border: Border.all(width:0.0),
        ),
        child: ListTile(
          subtitle: Text('コメントが存在しません。\n削除された可能性があります。'),
        ),
      );
    }

    bool couldRemove=myProfile.id==beacon.profile.id;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(width: 0.0),
      ),
      child: ListTile(
        leading: GestureDetector(
          child: Container(
            height: 40.0,
            width: 40.0,
            //IconButtonを使うと余白がおかしい
            //Material designの仕様
            //https://stackoverflow.com/questions/50381157/how-do-i-remove-flutter-iconbutton-big-padding
            child: ClipOval(
              child: NetworkImageModified(beacon.profile?.avatarUrl),
            ),
          ),
          onTap: (){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage(profile: beacon.profile,)),
            );
          },
        ),
        title: Text(beacon.profile?.id??''),
        subtitle: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.topLeft,
              child: Text(beacon.text),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                BookmarkButton(id: beacon.id,size: ACTIONS_ICON_SIZE,),
                IconButton(
                  icon:Icon(
                    Icons.remove_circle_outline,
                    color: Colors.grey[couldRemove?600:300],
                  ),
                  onPressed: couldRemove?(){
                    api.removeBeacon(id:beacon.id);
                  }:null,
                ),
                IconButton(
                  icon: Icon(
                    Icons.reply,
                  ),
                  onPressed: (){
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DetailPage(beacon: beacon)),
                    );
                  },
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BookmarkModel with ChangeNotifier{
  Api api;
  static List<String> bookmarks;
  static bool isBookmarkInitialize=false;

  BookmarkModel({@required this.api}){
    api.myProfileSubject.listen((profile){
      if(isBookmarkInitialize){
        return ;
      }
      bookmarks=profile?.bookmarks;
      bookmarks??=[];
    });
  }

  void pressed(String id){

    if(!bookmarks.remove(id)){
      bookmarks.add(id);
      api.addBookmark(id);
    }
    else{
      api.removeBookmark(id);
    }
    notifyListeners();
  }

  bool isBookmarked(String id){
    return bookmarks.contains(id);
  }
}

class BookmarkButton extends StatefulWidget{
  final String id;
  final double size;
  BookmarkButton({@required this.id,@required this.size});
  @override
  BookmarkButtonState createState()=>BookmarkButtonState();
}

class BookmarkButtonState extends State<BookmarkButton>{

  Api api;

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    api??=Provider.of<Api>(context);
  }

  @override
  Widget build(BuildContext context) {
    //var model=BookmarkModel();
    //model.getState(id);
    return IconButton(
      iconSize: widget.size,
      icon: Selector<BookmarkModel,bool>(
        selector: (context,BookmarkModel model){
          bool a=model.isBookmarked(widget.id);
          return a;
        },
        builder: (context,state,_){
          if(state){
            return Icon(Icons.favorite,color: Colors.red[600],);
          }
          else{
            return Icon(Icons.favorite_border,color: Colors.red[600],);
          }
        },
      ),
      onPressed: ()=>Provider.of<BookmarkModel>(context).pressed(widget.id),
    );
  }
}




class MainPage extends StatelessWidget{

  final Widget _timelinePage=TimelinePage();

  final Widget _mapPage= MapPage();

  final Widget _bookmarkPage=BookmarksPage();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Provider.of<Api>(context).indexSubject,
      initialData: Provider.of<Api>(context).indexSubject.value,
      builder: (context,snapshot){
        return Scaffold(
          appBar:AppBar(
            leading: IconButton(
              icon: Padding(
                  padding: EdgeInsets.all(1.0),
                  child: ClipOval(
                    child: NetworkImageModified(Provider.of<Api>(context).myProfileSubject.value?.avatarUrl),
                  )
              ),
              onPressed: (){
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfilePage(profile:Provider.of<Api>(context).myProfileSubject.value))
                );
              },
            ),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.cached),
                onPressed: (){
                  Provider.of<Api>(context).updateTimeline();
                },
              ),
              IconButton(
                icon: Icon(Icons.settings),
                onPressed: (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsPage()),
                  );
                },
              )
            ],
          ),
          body:IndexedStack(
            index: snapshot.data,
            children: [_timelinePage,_mapPage,_bookmarkPage],
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                  title: Text('Beacon'),
                  icon: Icon(Icons.message)
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.location_on),
                title: Text('Map'),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                title: Text('Setting'),
              ),
            ],
            currentIndex: snapshot.data,
            onTap: (int index)async{
              Provider.of<Api>(context).indexSubject.add(index);
            },
          ),
        );
      },
    );
  }
}

class ChangeRangeModel with ChangeNotifier{

  int range=1;
  bool isChanged=false;
  Api api;

  ChangeRangeModel({this.api});

  void add(){
    if(range>=100){
      range=100;
      return;
    }
    range+=1;
    isChanged=true;
    notifyListeners();
  }

  void sub(){
    if(range<=0){
      range=0;
      return;
    }
    range-=1;
    isChanged=true;
    notifyListeners();
  }

  void update(){
    if(api?.range==null){
      return;
    }
    api.range=range;
    api.updateTimeline();
    isChanged=false;
    notifyListeners();
  }

}


class ChangeRangeTile extends StatelessWidget{

  @override
  Widget build(context){
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(width: 0.0)),
      ),
      child:Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.remove),
              onPressed: (){
                Provider.of<ChangeRangeModel>(context,listen: false).sub();
              },
            ),
            Selector<ChangeRangeModel,int>(
              selector: (context,model){
                return model.range;
              },
              builder: (context,range,_){
                return Text('${range.toString()}km');
              },
            ),
            IconButton(
              icon: Icon(Icons.add),
              onPressed: (){
                Provider.of<ChangeRangeModel>(context,listen: false).add();
              },
            ),
            Selector<ChangeRangeModel,bool>(
              selector: (context,model){
                return model.isChanged;
              },
              builder: (context,isChanged,_){
                return FlatButton(
                  child: Text('更新'),
                  color:Colors.deepOrange[isChanged?600:400] ,
                  onPressed: isChanged ? (){
                    Provider.of<ChangeRangeModel>(context,listen: false).update();
                  }:null,
                );
              },
            ),
          ],
        ),
      )
    );
  }
}

class ProfilePage extends StatelessWidget{

  final Profile profile;

  ProfilePage({@required this.profile});

  @override
  Widget build(BuildContext context){

    if(profile==null){
      return NoSuchProfilePage();
    }

    List<Widget> actions;
    if(Provider.of<Api>(context).myProfileSubject.value?.id==profile.id){
      actions=<Widget>[
        FlatButton(
          color: Colors.white,
          child: Text('変更'),
          onPressed: (){
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) {
                      return EditProfilePage();
                    }
                )
            );
          },
        )
      ];
    }


    return Scaffold(
      appBar: AppBar(
          title: Text('ProfilePage'),
          actions: actions
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 200.0,
              height: 200.0,
              child: ClipOval(
                child: NetworkImageModified(profile.avatarUrl),
              ),
            ),
            Text('名前：${profile.name}'),
            Text('自己紹介：${profile.introduction}')
          ],
        ),
      ),
    );
  }
}



class EditProfilePage extends StatefulWidget{

  //EditProfilePage({Key key}):super(key:key);

  @override
  EditProfileState createState()=>EditProfileState();
}

class EditProfileState extends State<EditProfilePage>{

  final  choosedAvatarSubject=BehaviorSubject<File>.seeded(null);
  //Formで使う
  final formKey = GlobalKey<FormState>();


  void onSavePressed(Profile myProfile)async{

    //formの内容をチェック
    if(!formKey.currentState.validate()) {
      return ;
    }
    //問題なければ保存
    formKey.currentState.save();

    //プログレスバー表示
    var progressDialog=ProgressDialog(context,type: ProgressDialogType.Normal, isDismissible: false, showLogs: false);
    progressDialog.style(message: 'アップロード中');
    progressDialog.show();

    Api api=Provider.of<Api>(context);
    String avatarUrl;

    if(api?.user?.uid==null){
      return;
    }

    //アバターが選択されていればアップロード
    if(choosedAvatarSubject.value!=null){
      avatarUrl=await api.uploadImage(
          file: choosedAvatarSubject.value,
          collectionName: 'images',
          fileName: api.user.uid
      );
    }

    //アップロードが成功した場合キャッシュを消す
    //これをしないと画像が変更されない
    //ついでにプロフィールのアバターのurlを変更
    if(avatarUrl!=null){
      PaintingBinding.instance.imageCache.clear();
      myProfile.avatarUrl=avatarUrl;
    }

    //Profileもアップロード
    await Provider.of<Api>(context).uploadProfile(avatar:choosedAvatarSubject.value,profile:myProfile);

    //Provider.of<Api>(context).indexSubject.add(Provider.of<Api>(context).indexSubject.value);

    //プログレスバー非表示
    progressDialog.hide();

    Navigator.of(context).pop();
  }


  @override
  Widget build(BuildContext context) {

    //アップロード用のProfileを準備
    var myProfile=Provider.of<Api>(context).createMyProfileToEdit();

    Widget initialAvatar=myProfile.avatarUrl.length==0
        ?ClipOval(child: Image.asset('images/flutter_logo.png'),)
        :ClipOval(child: NetworkImageModified(myProfile.avatarUrl),);

    return StreamBuilder<File>(
      stream: choosedAvatarSubject,
      initialData: choosedAvatarSubject.value,
      builder: (context,snapshot){

        if(snapshot.hasError||snapshot.connectionState==ConnectionState.none){
          return ErrorOccurredPage(widgetName: 'EditProfilePage',);
        }

        if(snapshot.connectionState==ConnectionState.waiting){
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              FlatButton(
                color: Colors.white,
                child: Text('保存'),
                onPressed: () async {
                  onSavePressed(myProfile);
                },
              )
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              reverse: true,
              scrollDirection: Axis.vertical,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:<Widget>[
                  Container(
                    height: 40.0,
                    width: 40.0,
                    child: snapshot.data==null ?
                    initialAvatar :
                    ClipOval(
                      child: Image.file(snapshot.data),
                    ),
                  ),
                  SizedBox(
                    child: IconButton(
                      icon: Icon(Icons.photo),
                      onPressed: () async {
                        File file=await Provider.of<Api>(context).takeFileFromCamera();
                        if(file!=null){
                          choosedAvatarSubject.add(file);
                        }
                      },
                    ),
                  ),
                  Form(
                    key: formKey,
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: '名前　'),
                          maxLength: 32,
                          initialValue: '${myProfile.name}',
                          validator: (value){
                            if(value.length==0){
                              return '名前を入力してください。';
                            }
                            return null;
                          },
                          onSaved: (value){
                            myProfile.name=value;
                          },
                          autofocus: false,
                        ),
                        TextFormField(
                          keyboardType: TextInputType.multiline,
                          autofocus: false,
                          decoration: InputDecoration(
                            labelText: '紹介文',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 20,
                          maxLength: 256,
                          initialValue: '${myProfile.introduction}',
                          validator: (value){
                            if(value.length==0){return '紹介文を入力してください。';}
                            return null;
                          },
                          onSaved: (value){
                            myProfile.introduction=value;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose(){
    choosedAvatarSubject.close();
    super.dispose();
  }
}

class NoSuchProfilePage extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
          child:Text('プロフィールが存在しません。\n削除された可能性があります。')
      ),
    );
  }
}

class ErrorOccurredPage extends StatelessWidget{

  final String widgetName;

  ErrorOccurredPage({this.widgetName});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('{$widgetName}にてエラーが発生しました。'),
            Text('接続が中断されたなどの一時的な問題の場合、'),
            Text('アプリの再起動で修復できる場合があります。'),
            FlatButton(
              child: Text('再起動する'),
              onPressed: (){
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoadUserPage()),
                );
              },
            ),
            Text('再起動しても修復しない場合、'),
            Text('繰り返しエラーが発生する場合には'),
            Text('お手数ですが以下のメールアドレスまでご連絡お願いします。'),
            Text('チームがすぐに対応いたします。')
          ],
        )
      ),
    );
  }
}

class TimelinePage extends StatelessWidget{

  bool checkRemovable(Profile myProfile,Beacon beacon){
    if(myProfile==null||beacon==null){
      return false;
    }
    else{
      return myProfile.id==beacon.profile.id;
    }
  }

  @override
  Widget build(BuildContext context){
    var api=Provider.of<Api>(context);

    return Scaffold(
      body:StreamBuilder<List<Beacon>>(
        stream: api.timelineSubject.stream,
        builder: (context,snapshot){
          if(snapshot.hasError||snapshot.connectionState==ConnectionState.none){
            return ListTile(
              subtitle: Text('ERROR'),
            );
          }
          if(snapshot.connectionState==ConnectionState.waiting){
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          if(snapshot.data==null){
            return ListTile(
              subtitle: Text('コメントが存在しません。\n削除された可能性があります。'),
            );
          }
          log('timeline length:${snapshot.data.length}\n');
          return Padding(
            padding: EdgeInsets.only(bottom: 60.0),
            child:ListView.builder(
              itemCount: snapshot.data.length+1,
              itemBuilder: (context,index){
                if(index==0){
                  return ChangeNotifierProvider<ChangeRangeModel>(
                    create: (context)=>ChangeRangeModel(api: api),
                    child: ChangeRangeTile(),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(width: 0.0))
                  ),
                  child: BeaconTileProvider(
                    beacon: snapshot.data[index-1],
                  ),
                );
              },
            ),

          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'timelineButton',
        child: Icon(Icons.add),
        onPressed: (){
          Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RemainBeaconPage())
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatelessWidget{
  @override
  Widget build(context){
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FlatButton(
              child: Text('ログアウト'),
              onPressed: () async {
                await Provider.of<Api>(context).signOut();
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoadUserPage())
                );
              },
            ),
            FlatButton(
              child: Text('プロフィールを削除する'),
              onPressed: ()async{
                await Provider.of<Api>(context).deleteMyProfile();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context)=>LoadUserPage()),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

//StatefulWidgetにしないと
//GoogleMapが更新されない
class MapPage extends StatefulWidget {

  @override
  State<MapPage> createState() => MapState();
}

class MapState extends State<MapPage> {

  Api api;

  //最初のカメラの位置
  CameraPosition initialCameraPosition;

  //timelineのlistenをdisposeで解除するためのもの
  StreamSubscription timelineSubscription;

  //indexのlistenをdisposeで解除するためのもの
  StreamSubscription indexSubscription;

  //GoogleMapのカメラの位置とかを操作するもの
  Completer<GoogleMapController> controller=Completer();

  //GoogleMapを作り出すのに必要なものを集めたもの
  final markersSubject=BehaviorSubject<Set<Marker>>();

  bool _isPrepared=false;

  //カメラの位置を変える関数
  Future<void> changeCameraPosition(CameraPosition cameraPosition) async {
    await (await controller.future).animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  //カメラの位置を現在位置にする関数
  Future<void> updateCameraPosition() async{
    LatLng location=api.currentLocation.value;
    if(location!=null){
      await changeCameraPosition(CameraPosition(
          target: location,
          zoom: 17.0
      ));
    }
  }

  void prepareForMarkers({Function onTapMarker}){
    if(_isPrepared){
      return;
    }
    _listenTimeline(onTapMarker:onTapMarker);
    _listenIndex();
    _isPrepared=true;
  }

  void _listenTimeline({Function onTapMarker}){
    timelineSubscription=api.timelineSubject.listen((timeline){
      if(api.currentLocation.value==null||timeline==null){
        return;
      }
      initialCameraPosition??=CameraPosition(
        target: api.currentLocation.value,
        zoom: 17.0,
      );
      //Timelineからマーカーを作っていく
      var map = <MarkerId, Marker>{};
      timeline.forEach((beacon) {
        MarkerId markerId = MarkerId(beacon.id);
        Marker marker = Marker(
          markerId: markerId,
          position: LatLng(beacon.latitude, beacon.longitude),
          onTap: () {
            onTapMarker(beacon);
          },
        );
        map[markerId] = marker;
      });
      //mapComponent.isClosed==true
      //になることはない（disposeでtimelineSubscriptionがcancelされてるから）
      //しかし、念のためif文で除外
      if(!markersSubject.isClosed){
        //ここでGoogleMapのマーカーが更新される
        markersSubject.add(
            Set<Marker>.of(map.values)
        );
      }

    });
  }

  void _listenIndex(){

    //BottomuNavigationBarで選択されたindexを監視する
    indexSubscription=api.indexSubject.listen((index){

      //MainPageのタブで地図のボタンが押されたときに
      //カメラの位置を更新
      if(index==1){
        updateCameraPosition();
      }
    });

  }

  @override
  void dispose(){
    super.dispose();
    timelineSubscription.cancel();
    indexSubscription.cancel();
    markersSubject.close();
  }

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    api??=Provider.of<Api>(context);
  }

  @override
  Widget build(BuildContext context) {

    prepareForMarkers(
      onTapMarker: (beacon) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  DetailPage(beacon: beacon,)),
        );
      }
    );

    return Scaffold(
      body: StreamBuilder<Set<Marker>>(
        stream: markersSubject,
        builder: (context,snapshot){
          if(snapshot.hasError || snapshot.connectionState==ConnectionState.none){
            return Center(
              child: Text('ERROR'),
            );
          }
          if(snapshot.connectionState==ConnectionState.waiting||initialCameraPosition==null){
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          return GoogleMap(
              myLocationEnabled: true,
              onMapCreated: (googleMapController) {
                controller.complete(googleMapController);
              },
              initialCameraPosition: initialCameraPosition,
              mapType: MapType.terrain,
              markers: snapshot.data
          );

        },
      ),
    );
  }

}



class BookmarksPage extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    return Scaffold(
      body:StreamBuilder<List<Beacon>>(
        stream: Provider.of<Api>(context).bookmarksSubject,
        builder: (context,snapshot){
          if(snapshot.hasError||snapshot.connectionState==ConnectionState.none){
            return ListTile(
              subtitle: Text('ERROR'),
            );
          }
          if(snapshot.connectionState==ConnectionState.waiting){
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          if(snapshot.data==null){
            return ListTile(
              subtitle: Text('コメントが存在しません。\n削除された可能性があります。'),
            );
          }
          return ListView.builder(
            itemCount: snapshot.data.length,
            itemBuilder: (context,index){
              return Container(
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(width: 0.0))
                ),
                child: BeaconTileProvider(
                  beacon: snapshot.data[index],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ReplyModel{

  CollectionReference replyCollection;
  StreamSubscription subscription;
  final replyController = BehaviorSubject<List<Beacon>>();
  final Beacon beacon;
  final Api api;

  Future<List<Beacon>> getRepliesFromDocuments(List<DocumentSnapshot> documents) async{
    if(documents==null){
      return [];
    }

    List<Beacon> replies=[];
    await Future.forEach(documents,(document)async{
      if(!document.exists){
        return;
      }
      Profile profile=await api.getProfile(id: document['profileId']);
      if(profile==null){
        return;
      }
      replies.add(Beacon(
          id: document.documentID,
          profile: profile,
          latitude:0.0,
          longitude: 0.0,
          text: document['text'],
          distance: 0
      ));
    });
    return replies;
  }

  Future<bool> addReply(String text) async{

    var uid=api.user?.uid;
    if(uid==null){
      return false;
    }

    DocumentReference document = await replyCollection.add({
      'profileId':uid,
      'latitude': 0.0,
      'longitude': 0.0,
      'text':text
    });
    if(document==null){
      return false;
    }
    return true;
  }

  Future<void> removeReply(String id)async{
    if(id==null) {
      return;
    }
    await replyCollection.document(id).delete();
    return;
  }

  ReplyModel({@required this.beacon,@required this.api}){
    replyCollection=Firestore.instance
        .collection('beacon56784').document(beacon.id)
        .collection('reply');
    subscription=replyCollection.snapshots().listen((snapshot)async{
      replyController.add(await getRepliesFromDocuments(snapshot.documents));
    });
  }
  void dispose(){
    subscription.cancel();
    replyController.close();
  }
}

class DetailPage extends StatefulWidget{

  final Beacon beacon;
  DetailPage({@required this.beacon});

  @override
  DetailState createState()=>DetailState();
}


class DetailState extends State<DetailPage>{

  ReplyModel model;

  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    model??=ReplyModel(beacon:widget.beacon,api: Provider.of<Api>(context));
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
      ),
      body: StreamBuilder(
        stream: model.replyController.stream,
        builder: (context,snapshot){

          if(snapshot.hasError
              ||snapshot.connectionState==ConnectionState.none
              ||snapshot.data==null
              ||widget.beacon==null){
            return Center(
              child: Text('リプライを取得できませんでした。'),
            );
          }

          if(snapshot.connectionState==ConnectionState.waiting){
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data.length+1,
            itemBuilder: (context,index){
              if(index==0) {
                return BeaconTileProvider(beacon: widget.beacon,);
              }
              Beacon reply=snapshot.data[index-1];
              return ReplyTile(
                beacon: widget.beacon,
                reply: reply,
                onRemovePressed: (){
                  model.removeReply(reply.id);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: (){
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context){
              return Provider<ReplyModel>.value(
                value: model,
                child: WriteReplyPage(),
              );
            }),
          );
        },
      ),
    );
  }
}

class WriteReplyPage extends StatefulWidget{
  @override
  WriteReplyPageState createState()=>WriteReplyPageState();
}

class WriteReplyPageState extends State<WriteReplyPage>{
  final _textController = TextEditingController();


  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
          actions:<Widget>[
            Container(
              margin: EdgeInsets.all(10.0),
              child: RaisedButton(
                child:Text('返信する'),
                shape: StadiumBorder(),
                color: Colors.white,
                onPressed: ()async {

                  //プログレスバー表示
                  var progressDialog=ProgressDialog(context,type: ProgressDialogType.Normal, isDismissible: false, showLogs: false);
                  progressDialog.style(message: 'アップロード中');
                  progressDialog.show();

                  await Provider.of<ReplyModel>(context).addReply(_textController.text);
                  _textController.clear();
                  progressDialog.hide();
                  Navigator.pop(context);
                },
              ),
            ),

          ]
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: TextField(
          autofocus: true,
          keyboardType: TextInputType.multiline,
          maxLines: 100,
          controller: _textController,
          decoration: InputDecoration(
            hintText: 'ここらへんに誰かいる？',
          ),
        ),
      ),
    );
  }
  @override
  void dispose(){
    _textController.dispose();
    super.dispose();
  }
}



class RemainBeaconPage extends StatefulWidget{
  @override
  RemainBeaconState createState()=>RemainBeaconState();
}

class RemainBeaconState extends State<RemainBeaconPage>{
  final _textController = TextEditingController();


  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
          actions:<Widget>[
            Container(
              margin: EdgeInsets.all(10.0),
              child: RaisedButton(
                child:Text('足跡を残す'),
                shape: StadiumBorder(),
                color: Colors.white,
                onPressed: ()async {
                  //プログレスバー表示
                  var progressDialog=ProgressDialog(context,type: ProgressDialogType.Normal, isDismissible: false, showLogs: false);
                  progressDialog.style(message: 'アップロード中');
                  progressDialog.show();

                  await Provider.of<Api>(context).addBeacon(_textController.text);
                  _textController.clear();

                  progressDialog.hide();

                  Navigator.pop(context);
                },
              ),
            ),

          ]
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: TextField(
          autofocus: true,
          keyboardType: TextInputType.multiline,
          maxLines: 100,
          controller: _textController,
          decoration: InputDecoration(
            hintText: 'ここらへんに誰かいる？',
          ),
        ),
      ),
    );
  }
  @override
  void dispose(){
    _textController.dispose();
    super.dispose();
  }
}

class BeaconTileProvider extends StatelessWidget{

  final Beacon beacon;

  BeaconTileProvider({@required this.beacon});

  static final Map<String,BeaconTile> _items=<String,BeaconTile>{};

  @override
  Widget build(BuildContext context) {

    if(beacon==null){
      return ListTile(
        subtitle: Text('ビーコンが存在しません。\n削除された可能性があります。'),
      );
    }
    if(_items[beacon.id]!=null){
      return _items[beacon.id];
    }


    return FutureBuilder<Beacon>(
      future:Provider.of<Api>(context).getBeaconFromId(id:beacon.id),
      builder: (context,snapshot){
        if(snapshot.hasError||snapshot.connectionState==ConnectionState.none||snapshot.data==null){
          return ListTile(
            subtitle: Text('ERROR'),
          );
        }
        if(snapshot.connectionState==ConnectionState.waiting){
          return ListTile(
            subtitle: Text('Loading...'),
          );
        }
        _items[beacon.id]=BeaconTile(beacon:snapshot.data);
        return _items[beacon.id];
      },
    );
  }
}

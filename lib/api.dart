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
import 'package:flutter/services.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';

class Api{

  //
  final indexSubject = BehaviorSubject<int>.seeded(0);
  final timelineSubject=BehaviorSubject<List<Beacon>>();
  final currentLocation=BehaviorSubject<LatLng>();
  final allBeacons=BehaviorSubject<List<DocumentSnapshot>>();
  final myProfileSubject=BehaviorSubject<Profile>();
  final bookmarksSubject=BehaviorSubject<List<Beacon>>.seeded([]);

  StreamSubscription myProfileSubscription;



  FirebaseUser user;
  GoogleSignIn googleUser;
  int range=100;


  CollectionReference _beaconCollection=Firestore.instance.collection('beacon56784');
  CollectionReference _profileCollection=Firestore.instance.collection('profile');
  bool _isMonitoringBeaconsAndLocationStarted=false;
  bool _isBeaconsOrLocationUpdated=false;
  bool _isBookmarksInitialized=false;

  Api(){
    _checkLocationPermission();
    _listenLocation();
    _listenAllBeacons();
  }


  Future<bool> initUser() async {
    user = await FirebaseAuth.instance.currentUser();
    if(user==null){
      return false;
    }
    myProfileSubscription?.cancel();
    _listenMyProfile();
    return true;
  }

  //初めてアプリをインストールしてmyProfileがそもそも存在しない場合がある。
  //それに対処するための関数
  Future<bool> initMyProfile() async {
    if(myProfileSubject.value!=null){
      return true;
    }
    else{
      var myProfile = await getProfile(id: user?.uid);
      if(myProfile==null){
        return false;
      }
      else{
        myProfileSubject.add(myProfile);
        return true;
      }
    }
  }



  //googleアカウントでログイン
  Future<bool> signInGoogle() async {

    try{
      googleUser = GoogleSignIn();

      final GoogleSignInAuthentication googleAuth = await (await googleUser.signIn()).authentication;
      final AuthCredential credential = GoogleAuthProvider.getCredential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      user=(await FirebaseAuth.instance.signInWithCredential(credential))?.user;
    }
    catch(e){
      return Future.value(false);
    }

    return Future.value(user!=null);
  }

  Future<void> signOut()async{
    await FirebaseAuth?.instance?.signOut();
    await googleUser?.signOut();
  }

  Future<void> deleteMyProfile()async{
    await signOut();
    await _profileCollection.document(user?.uid).delete();
    await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    //myProfileSubject.add(null);
  }

  //ProfileのidからProfileを返す
  //存在しなかったらnull
  Future<Profile> getProfile({@required String id}) async {
    if(id==null){
      return null;
    }
    DocumentSnapshot document = await _profileCollection.document(id).get();
    if(!document.exists){
      return null;
    }
    return fromDocumentSnapshotIntoProfile(document);
  }

  Profile fromDocumentSnapshotIntoProfile(DocumentSnapshot document){
    String rawBookmarks=document['bookmarks'];
    List<String> bookmarks=<String>[];
    if(rawBookmarks!=null&&rawBookmarks.length!=0){
      bookmarks=rawBookmarks.split(' ');
    }
    return Profile(
        avatarUrl: document['avatarUrl'],
        name: document['name'],
        introduction: document['introduction'],
        id: document['id'],
        bookmarks: bookmarks
    );
  }



  //Profileをアップロードする関数
  //firestoreの仕様上その時アップロードに失敗しても
  //他のタイミングで再度試みてくれる
  Future<void> uploadProfile({File avatar,Profile profile}) async{

    if(profile!=null) {
      await _profileCollection.document(profile.id).setData({
        'introduction': profile.introduction,
        'name': profile.name,
        'id': profile.id,
        'avatarUrl': profile.avatarUrl,
        'bookmarks':profile.bookmarks.join(' ')
      });
    }
  }

  Profile createMyProfileToEdit() {
    var uid=user?.uid;
    if(myProfileSubject.value==null){
      return Profile(
        id: uid,
        avatarUrl: 'https://cdn-images-1.medium.com/max/1200/1*ilC2Aqp5sZd1wi0CopD1Hw.png',
        introduction: '',
        name: '',
        bookmarks: []
      );
    }
    else{
      return Profile.clone(myProfileSubject.value);
    }
  }

  //カメラで撮影した写真(File)を選択する
  Future<File> takeFileFromCamera() async {

    //pickImageには例外処理が必要
    var imageFile = await ImagePicker.pickImage(source: ImageSource.camera);

    if(imageFile==null){
      return null;
    }
    return  await ImageCropper.cropImage(
        sourcePath: imageFile.path,
        cropStyle: CropStyle.circle,
        aspectRatio: CropAspectRatio(ratioX: 1.0,ratioY: 1.0)
    );
  }



  //Fileをアップロードする関数
  //失敗した場合nullを返す
  Future<String> uploadImage({@required File file,@required String collectionName,@required String fileName}) async {
    final StorageReference ref = FirebaseStorage.instance.ref().child(collectionName).child(fileName);
    final StorageUploadTask uploadTask = ref.putFile(file);
    StorageTaskSnapshot snapshot = await uploadTask.onComplete;
    if (snapshot.error == null) {
      return await snapshot.ref.getDownloadURL();
    }
    else{
      return null;
    }
  }

  Future<Beacon> getBeaconFromId({@required String id}) async {
    if(id==null){
      return null;
    }
    DocumentSnapshot document = await _beaconCollection.document(id).get();
    if(document==null){
      return null;
    }
    return await getBeaconFromDocument(document:document);
  }

  Future<Beacon> getBeaconFromDocument({@required DocumentSnapshot document}) async{
    if(currentLocation.value==null){
      log('currenLocation.value is null\n\n');
      return null;
    }
    if(!document.exists){
      log('at getBeaconFromDocument  document doesnt exists\n\n');
      return null;
    }
    else{
      Profile profile=await getProfile(id: document['profileId']);
      if(profile==null){
        log('profile is null\n\n');
        return null;
      }
      return Beacon(
          id: document.documentID,
          profile: profile,
          latitude:document['latitude'],
          longitude: document['longitude'],
          text: document['text'],
          distance: await  Geolocator().distanceBetween(currentLocation.value.latitude, currentLocation.value.longitude,document['latitude'] ,document['longitude'])
      );
    }
  }

  Future<bool> addBookmark(String id)async{

    var beacon=await getBeaconFromId(id: id);

    if(beacon!=null){

      var bookmark=bookmarksSubject.value;
      bookmark.removeWhere((_beacon)=>_beacon.id==id);
      bookmark.add(beacon);
      bookmarksSubject.add(bookmark);

      var profile=myProfileSubject.value;
      profile.bookmarks.remove(id);
      profile.bookmarks.add(id);
      uploadProfile(profile: profile);

      return true;
    }
    else{

      return false;

    }
  }

  void removeReply({String beaconId,String replyId}){

  }

  void removeBookmark(String id){
    List<Beacon> bookmarks=bookmarksSubject.value;
    bookmarks.removeWhere((beacon)=>beacon.id==id);
    bookmarksSubject.add(bookmarks);

    var profile=myProfileSubject.value;
    if(profile==null){
      return null;
    }
    profile.bookmarks.remove(id);
    uploadProfile(profile: profile);
  }
  
  
  Future<void> addBeacon(String text) async{
    var uid=user?.uid;
    var location=currentLocation.value;
    if (location==null||uid==null){
      return null;
    }

    DocumentReference document = await _beaconCollection.add({
      'profileId':uid,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'text':text
    });

    Profile profile=myProfileSubject.value;
    if(document==null||profile==null){
      return null;
    }
    Beacon beacon=Beacon(
        id: document.documentID,
        profile: profile,
        latitude:location.latitude,
        longitude: location.longitude,
        text: text,
        distance: 0.0
    );
    List<Beacon>timeline=timelineSubject.value;
    timeline.add(beacon);
    timelineSubject.add(timeline);
  }





  void _checkLocationPermission(){
    //ここで位置情報の権限を確認する
    PermissionHandler().checkPermissionStatus(PermissionGroup.location)
        .then((status) {
      if(status != PermissionStatus.granted){
        //拒否されたら権限を要求する
        _requestLocationPermission();
      }
    });
  }

  void _requestLocationPermission(){
    //ここで位置情報を許可しますか？みたいな画面が出る。
    PermissionHandler().requestPermissions([PermissionGroup.location]).
    then((statuses){
      if(statuses[PermissionGroup.location]!=PermissionStatus.granted){
        //ここで設定画面を出して許可してもらえるように促す。
        PermissionHandler().openAppSettings();
      }
    });
  }

  void _listenLocation(){

    Geolocator().getPositionStream(LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 0))
        .listen((Position position){

      currentLocation.add(LatLng(position.latitude, position.longitude));

      _isBeaconsOrLocationUpdated=true;

      //startMonitoringBeaconsAndLocation();

      if(timelineSubject.value==null){
        updateTimeline();
      }

    });
  }

  void _listenAllBeacons(){

    _beaconCollection.snapshots().listen((querySnapshot){

      allBeacons.add(querySnapshot.documents);

      _isBeaconsOrLocationUpdated=true;

      //startMonitoringBeaconsAndLocation();

      if(timelineSubject.value==null){
        updateTimeline();
      }

    });
  }

  //_listenMyProfile内で使われている。
  //ブックマークを初期化する関数
  //ついでに不必要なブックマークを削除してプロフィールを更新する。
  void initBookmarks()async{
    if(_isBookmarksInitialized||myProfileSubject.value==null){
      return;
    }
    var bookmarks=myProfileSubject.value.bookmarks;
    if(bookmarks==null){
      return ;
    }
    bookmarks=bookmarks.toSet().toList();
    List<String> availableBookmarkId=[];
    List<Beacon> availableBookmark=[];
    await Future.forEach(bookmarks,(id) async {

      Beacon beacon= await getBeaconFromId(id:id);

      if(beacon!=null){
        availableBookmarkId.add(id);
        availableBookmark.add(beacon);
      }

    });
    bookmarksSubject.add(availableBookmark);
    Profile profileToUpload=myProfileSubject.value;
    profileToUpload.bookmarks=availableBookmarkId;
    uploadProfile(profile:profileToUpload);
    _isBookmarksInitialized=true;
  }


  void _listenMyProfile()async{
    var uid=user?.uid;
    if(uid==null){
      return;
    }
    myProfileSubscription=_profileCollection.document(uid).snapshots().listen((document){
      if(!document.exists){
        return;
      }
      myProfileSubject.add(fromDocumentSnapshotIntoProfile(document));
      initBookmarks();
    });
  }


  void removeBeacon({@required String id}){

    List<Beacon> timeline=timelineSubject.value;
    timeline.removeWhere((beacon)=>beacon.id==id);
    timelineSubject.add(timeline);

    List<Beacon> bookmarks=bookmarksSubject.value;
    bookmarks.removeWhere((beacon)=>beacon.id==id);
    bookmarksSubject.add(bookmarks);

    _beaconCollection.document(id).delete();
  }


//currentLocationとallBeaconsからtimelineを作成
  void updateTimeline() async{

    if(currentLocation.value==null||allBeacons.value==null) {
      return;
    }

    List<Beacon> nextTimeline=[];

    await Future.forEach(allBeacons.value,(DocumentSnapshot document) async {

      if(document==null){
        log('document is null at updateTimeline.\nsomething wrong\n');
        return;
      }

      Beacon beacon= await getBeaconFromDocument(document:document);

      if(beacon==null){
        log('beacon is null at updateTimeline.\n\n');
        return;
      }

      if(beacon.distance>range*1000.0){
        return;
      }

      nextTimeline.add(beacon);

    });

    nextTimeline.sort((a,b) => a.distance.compareTo(b.distance));

    timelineSubject.add(nextTimeline);
  }

  void startMonitoringBeaconsAndLocation(){

    if(currentLocation.value==null||allBeacons.value==null||_isMonitoringBeaconsAndLocationStarted) {
      return;
    }

    Timer.periodic(Duration(seconds: 2), (timer)async{

      //allBeaconsとcurrentLocationの両方とも更新されていなければ
      //更新する必要がない
      if(!_isBeaconsOrLocationUpdated){
        return;
      }

      updateTimeline();

      //falseに初期化
      _isBeaconsOrLocationUpdated=false;

    });

    _isMonitoringBeaconsAndLocationStarted=true;

  }

  void dispose(){
    indexSubject.close();
    timelineSubject.close();
    currentLocation.close();
    allBeacons.close();
    myProfileSubject.close();
    bookmarksSubject.close();
  }
}


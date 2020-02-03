import 'dart:io';
import 'dart:math';
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
import 'dart:developer' as developer;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';



//firestore上では
//String avatar
//String name
//String introduction
//String id
class Profile{
  String avatarUrl;
  String name;
  String introduction;
  String id;
  List<String> bookmarks;
  Profile({@required this.avatarUrl,@required this.name,@required this.introduction,@required this.id,@required this.bookmarks});
  Profile.clone(Profile profile):this(
    avatarUrl:profile.avatarUrl,
    name:profile.name,
    introduction:profile.introduction,
    id:profile.id,
    bookmarks:profile.bookmarks
  );
}

class MapPageComponent {
  LatLng latlng;
  List<Beacon> timeline;
  MapPageComponent({@required  this.latlng, @required this.timeline});
}


//firestore上では
//double longitude
//double latitude
//String text
//String footprintId
class Beacon{
  String id;
  Profile profile;
  double longitude,latitude;
  String text='';
  double distance;
  Beacon({@required this.id,@required this.profile,@required this.longitude,@required this.latitude,@required this.text,@required this.distance});
}


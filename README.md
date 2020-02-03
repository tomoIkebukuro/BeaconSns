# BeaconSns
___
#### ※注意事項※
セキュリティ上の理由でgoogle-services.jsonとAndroidManifest.xmlを削除しています。実際に動作させる際には[firebase](https://pub.dev/packages/google_maps_flutter)を[google map](https://pub.dev/packages/google_maps_flutter)を参考にして新しくファイルを作ってください。
___
#### はじめに
flutterとfirebaseを使って制作されたsnsアプリです。実際の現在地周辺のコメントを表示し、Google Mapを使って表示します。近くの人と繋がりたいという需要はあるにも関わらず、それを実現したsnsがなかったので制作しました。今後はChangeNotifierProviderを使ってソースコードの書き換えを考えています。開発環境は以下の通りです。
~~~
%flutter doctor
Doctor summary (to see all details, run flutter doctor -v):
[√] Flutter (Channel stable, v1.9.1+hotfix.6, on Microsoft Windows [Version 10.0.17763.973], locale ja-JP)

[!] Android toolchain - develop for Android devices (Android SDK version 29.0.2)
    ! Some Android licenses not accepted.  To resolve this, run: flutter doctor --android-licenses
[√] Android Studio (version 3.5)
[√] VS Code (version 1.41.1)
[!] Connected device
    ! No devices available
~~~
#### 機能
##### sns認証
手軽なログインができるsns認証を利用しています。現在Googleアカウントのみですが、今後twitterとfacebookもサポートする予定です。
![pic1](https://user-images.githubusercontent.com/59225570/73656434-76005b00-46d3-11ea-85f8-803ae5d6863e.jpg)
###### タイムライン
twitterに似た雰囲気のタイムラインです。受信半径を設定できます。例えば1kmに設定すれば現在位置から半径1km以内のコメントを拾います。近い順です。また、返信も投稿できるようになっています。これらの内容はfirestoreに保存されます。今後は地図ボタンを設置して地図で見れるようにします。あとデザイン(^^;...
![pic2](https://user-images.githubusercontent.com/59225570/73656454-80baf000-46d3-11ea-8778-63b01283b2b0.jpg)
###### 写真投稿機能
写真はfirestorageに保存します。カメラの権限の許可をユーザに催促したりもします。画像はプロフィール用の写真を設定しているところです。ちゃんと円形に切り取ることもできます。packageの力を借りてるだけですけどね...
![pic3](https://user-images.githubusercontent.com/59225570/73656462-84e70d80-46d3-11ea-8118-7727e3eac485.jpg)
###### その他機能
ブックマーク機能、ログアウト機能などがあります。
___
#### 最後に
BeaconSnsはまだ開発途中です。ソースコードもハリケーンが過ぎ去った街みたいになってますが、改良していきます。今後にご期待ください...

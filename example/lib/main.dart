import 'package:example/pages/article_picker_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:type_ahead_text_field/type_ahead_text_field.dart';
import 'package:rxdart/rxdart.dart';

import 'pages/simple_user_tag_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String title;

  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          children: [
            TextButton(onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => SimpleUserTagPage(title: 'Simple User Tag',)));
            }, child: Text('Simple User Tag Page')),
            SizedBox(
              height: 50,
            ),
            TextButton(onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ArticlePickerPage()));
            }, child: Text('Article Picker Page')),
          ],
        )
      ),
    );
  }
}

import 'package:blackjack/logic/table.dart';
import 'package:flutter/material.dart';


// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

void main() {
  runApp(
    MaterialApp(
      home: Scaffold(
        // appBar: PreferredSize(
        //   preferredSize: Size.fromHeight(56),
        //   child: AppBar(
        //     title: Text("Blackjack Strategy & Card Counting Trainer"),
        //     backgroundColor: Colors.blue,
        //   ),
        // ),
        body: BlackjackTable(),
      ),
    ),
  );
}

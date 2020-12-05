import 'package:ESOF/auth/Authentication.dart';
import 'package:ESOF/database/databaseService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import '../widgets/feed/recommended_carousel.dart';
import '../widgets/feed/top_rated_carousel.dart';
import '../widgets/feed/coming_next_carousel.dart';

class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final int minRate = 4;

  List<DocumentSnapshot> filterTopRate(
      List<DocumentSnapshot> totalConferences) {
    return totalConferences
        .where((conference) => conference['rate'] > minRate)
        .toList();
  }

  List<DocumentSnapshot> filterComingNext(
      List<DocumentSnapshot> totalConferences) {
    return totalConferences.where((conference) {
      DateTime confTime = DateTime.fromMillisecondsSinceEpoch(
          conference['date'].seconds * 1000);

      return confTime.compareTo(DateTime.now()) > 0;
    }).toList();
  }

  bool checkConfTag(List<String> confTags, List<String> userFavoriteTags) {
    for (String confTag in confTags)
      if (userFavoriteTags.contains(confTag.toUpperCase())) return true;

    return false;
  }

  List<DocumentSnapshot> filterRecommended_Tags(
      List<DocumentSnapshot> totalConferences, List<String> userFavoriteTags) {
    return totalConferences.where((conference) {
      List<String> separatedTags =
          conference['tag'].split(new RegExp(r'; |, |\*|\n| '));
      return checkConfTag(separatedTags, userFavoriteTags);
    }).toList();
  }

  List<DocumentSnapshot> filterRecommended_NotRatedYet(
      List<DocumentSnapshot> totalConferences,
      List<DocumentReference> userRatedConfs) {
    return totalConferences.where((conference) {
      return !userRatedConfs.contains(conference.reference);
    }).toList();
  }

  List<DocumentSnapshot> filterRecommended(
      List<DocumentSnapshot> totalConferences,
      List<String> userFavoriteTags,
      List<DocumentReference> userRatedConfs) {
    // print(totalConferences);
    List<DocumentSnapshot> totalRecommendedTags = filterRecommended_Tags(
        totalConferences, userFavoriteTags); // Contains Favorite Tags
    // print(totalRecommendedTags);
    List<DocumentSnapshot> totalRecommendedRate =
        filterTopRate(totalRecommendedTags); // Rate > minRate(4)
    // print(totalRecommendedRate);
    List<DocumentSnapshot> totalRecommendedComingNext =
        filterComingNext(totalRecommendedRate); // ComingNext
    // print(totalRecommendedComingNext);
    List<DocumentSnapshot> totalRecommended = filterRecommended_NotRatedYet(
        totalRecommendedComingNext, userRatedConfs); // Not rated yet!

    return totalRecommended;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: new StreamBuilder(
          stream:
              FirebaseFirestore.instance.collection("Conference").snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(),
              );
            } else {
              // filterRecommended(snapshot.data.documents, userFavoriteTags);
              return SafeArea(
                child: ListView(
                  padding: EdgeInsets.symmetric(vertical: 5.0),
                  children: <Widget>[
                    // We still need to parse the documents regarding each Category!
                    FutureBuilder(
                        future: Future.wait([
                          DatabaseService.getUserFavoriteTags(
                              AuthService.auth.currentUser.uid),
                          DatabaseService.getUserRatedConfs(
                              AuthService.auth.currentUser.uid)
                        ]),
                        builder:
                            (context, AsyncSnapshot<List<dynamic>> snapTags) {
                          // snapTags.data[0] -> getUserFavoriteTags
                          // snapTags.data[1] -> getUserRatedConfs
                          if (snapTags.hasData)
                            return RecommendedCarousel(filterRecommended(
                                snapshot.data.documents,
                                snapTags.data[0],
                                snapTags.data[1]));
                          else
                            return Center(
                                child:
                                    CircularProgressIndicator()); // passar as conferencias ordenadas por recomendação
                        }),
                    //TopRatedCarousel(),
                    TopRatedCarousel(filterTopRate(snapshot.data
                        .documents)), // passar as conferencias ordenadas por rating
                    //ComingNextCarousel(),
                    ComingNextCarousel(filterComingNext(snapshot.data
                        .documents)), // passar as conferencias ordenadas por data
                  ],
                ),
              );
            }
          }),
      resizeToAvoidBottomPadding: false,
    );
  }
}

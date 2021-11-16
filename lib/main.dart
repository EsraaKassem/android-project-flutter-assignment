import 'dart:io';
import 'dart:ui';

import 'package:english_words/english_words.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hello_me/AuthRepository.dart';
import 'package:provider/provider.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
                body: Center(
                    child: Text(snapshot.error.toString(),
                        textDirection: TextDirection.ltr)));
          }
          if (snapshot.connectionState == ConnectionState.done) {
            return MyApp();
          }
          return Center(child: CircularProgressIndicator());
        },
    );
  }
}

// #docregion MyApp

class MyApp extends StatelessWidget {
  // #docregion build
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthRepository>(
            create: (_) => AuthRepository(FirebaseAuth.instance),
        ),
         StreamProvider(create: (context)=>context.read<AuthRepository>().authStateChanges, initialData: null,)
      ],
        child:Consumer<AuthRepository>(builder: (context, login, _)=>
            MaterialApp(
          title: 'Startup Name Generator',
          theme: ThemeData(
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          //home: AuthenticaionWrapper(),
          initialRoute: '/',
          routes: {
            '/': (context) => RandomWords(),
            '/login': (context) => LoginScreen(),
          },
        )),

      );
  }
// #enddocregion build
}
// #enddocregion MyApp

// #docregion RWS-var
class _RandomWordsState extends State<RandomWords> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _suggestions = <WordPair>[];
  var _saved = Set<WordPair>();
  final _biggerFont = const TextStyle(fontSize: 18.0);
  var canDrag = true;
  SnappingSheetController sheetController = SnappingSheetController();

// #docregion RWS-build
  @override
  Widget build(BuildContext context) {
     final firebaseUser= context.watch<User?>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.star),
            onPressed:(firebaseUser!=null) ? _pushSaved:_pushSavedOld,
            tooltip: 'Saved Suggestions',
          ),
          IconButton(
            icon:  (firebaseUser!=null) ? const Icon(Icons.exit_to_app):const Icon(Icons.login),
            onPressed:(firebaseUser!=null) ? _pushLogout: _loginScreen,
            tooltip: 'Login',
          ),
        ],
      ),
      body: GestureDetector(
          child: SnappingSheet(
            controller: sheetController,
            snappingPositions: [
              SnappingPosition.pixels(
                  positionPixels: 220,
                  snappingCurve: Curves.bounceOut,
                  snappingDuration: Duration(milliseconds: 350)),
              SnappingPosition.factor(
                  positionFactor: 1.1,
                  snappingCurve: Curves.easeInBack,
                  snappingDuration: Duration(milliseconds: 1)),
            ],
            lockOverflowDrag: true,
            child: _buildSuggestions(),
            sheetBelow: AuthRepository.instance().status == Status.Authenticated
                ? SnappingSheetContent(
              draggable: canDrag,
              child: Container(
                color: Colors.white,
                child: ListView(
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      Column(children: [
                        Row(children: <Widget>[
                          Expanded(
                            child: Container(
                              color: Colors.grey,
                              height: 60,
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Flexible(
                                      flex: 3,
                                      child: Center(
                                        child: Text(
                                            "Welcome back, " +
                                                AuthRepository.instance().getUserName().toString(),
                                            style: TextStyle(
                                                fontSize: 16.0)),
                                      )),
                                  IconButton(
                                    icon: Icon(Icons.keyboard_arrow_up),
                                    onPressed: null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                        Row(children: <Widget>[
                          FutureBuilder(
                            future: AuthRepository.instance().getImageUrl(),
                            builder: (BuildContext context,
                                AsyncSnapshot<String> snapshot) {
                              return CircleAvatar(
                                radius: 50.0,
                                backgroundImage: snapshot.data != null
                                    ? NetworkImage(snapshot.data!)
                                    : null,
                              );
                            },
                          ),
                          Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(AuthRepository.instance().getUserName().toString(),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15))),
                        ]),
                        Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              MaterialButton(
                                onPressed: () async {
                                  FilePickerResult? result =
                                  await FilePicker.platform
                                      .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'png',
                                      'jpg',
                                      'gif',
                                      'bmp',
                                      'jpeg',
                                      'webp'
                                    ],
                                  );
                                  File file;
                                  if (result != null) {
                                    file =
                                        File(result.files.single.path.toString());
                                    AuthRepository.instance().uploadNewImage(file);
                                  } else {
                                    const snackBar = SnackBar(content: Text('No image selected '));
                                    ScaffoldMessenger.of(context).showSnackBar(snackBar);
                                }},
                                textColor: Colors.white,
                                padding: EdgeInsets.only(
                                    left: 5.0,
                                    top: 3.0,
                                    bottom: 5.0,
                                    right: 8.0),
                                child: Container(
                                 color:Colors.blue,
                                  padding: const EdgeInsets.all(5.0),
                                  child: const Text('Change Avatar',
                                      style: TextStyle(fontSize: 17)),
                                ),
                              ),
                            ]),
                      ]),
                    ]),
              ),
              //heightBehavior: SnappingSheetHeight.fit(),
            )
                : null,
          ),
          onTap: () =>
          {
            setState(() {
              if (canDrag == false) {
                canDrag = true;
                sheetController.snapToPosition(SnappingPosition.factor(
                  positionFactor: 0.323,
                ));
              } else {
                canDrag = false;
                sheetController.snapToPosition(SnappingPosition.factor(
                    positionFactor: 0.089,
                    snappingCurve: Curves.easeInBack,
                    snappingDuration: Duration(milliseconds: 1)));
              }
            }),
          }),
    );
  }
  // #enddocregion RWS-var

  // #docregion _buildSuggestions
  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemBuilder: /*1*/ (context, i) {
          if (i.isOdd) return const Divider(); /*2*/
          final index = i ~/ 2; /*3*/
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10)); /*4*/
          }

            return _buildRow(_suggestions[index]);
        });
  }
  // #enddocregion _buildSuggestions

  // #docregion _buildRow
  Widget _buildRow(WordPair pair) {
    final firebaseUser= context.watch<User?>();
    final alreadySaved = _saved.contains(pair);
    final alreadySavedData = (AuthRepository.instance().status == Status.Authenticated && AuthRepository.instance().getData().contains(pair));
    final isSaved = (alreadySaved || alreadySavedData);
    if(alreadySaved && !alreadySavedData){
      if(firebaseUser!=null){
      AuthRepository.instance().addpair(pair.toString(), pair.first, pair.second);}
    }
    return  ListTile(
        title: Text(
          pair.asPascalCase,
          style: _biggerFont,
        ),
        trailing: Icon(
          isSaved ? Icons.star : Icons.star_border,
          color: isSaved ? Colors.deepPurple : null,
          semanticLabel: isSaved ? 'Remove from saved' : 'Save',
        ),
        onTap: () {
          setState(() {
              if (isSaved) {
                _saved.remove(pair);
                if(firebaseUser!=null){
                AuthRepository.instance().removepair(pair.toString());
                }
              } else {
                _saved.add(pair);
                if(firebaseUser!=null) {
                  AuthRepository.instance().addpair(pair.toString(), pair.first, pair.second);
                }
              }
          });
        },
    );

  }
  // #enddocregion _buildRow


  // #enddocregion RWS-build
  void _pushSavedOld(){
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final tiles = _saved.map(
                (pair) {
              return  Dismissible(
                child:ListTile(
                    title: Text(
                      pair.asPascalCase,
                      style: _biggerFont,
                    )),
                background: Container(
                  color: Colors.deepPurple,
                  child: Row(
                    children:const <Widget> [
                      Icon(Icons.delete,color: Colors.white,),
                      Text('Delete Suggestion',style: TextStyle(color: Colors.white),)
                    ],
                  ),
                ),
                secondaryBackground: Container(
                  color: Colors.deepPurple,
                  child: Row(
                    mainAxisAlignment:MainAxisAlignment.end ,
                    children:const <Widget> [
                      Icon(Icons.delete,color: Colors.white,),
                      Text('Delete Suggestion',style: TextStyle(color: Colors.white),)
                    ],
                  ),
                ),
                key: ValueKey<WordPair>(pair),
                onDismissed: (DismissDirection direction) {
                  setState(() {
                    _saved.remove(pair);
                  });
                },
                confirmDismiss:(DismissDirection direction)async {
                  return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Delete Suggestion'),
                          content: Text(
                              'Are you sure you want to delete $pair from your saved suggestions?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                          ],
                        );
                      }
                  );
                },
              );
            },
          );
          final divided = tiles.isNotEmpty
              ? ListTile.divideTiles(
            context: context,
            tiles: tiles,
          ).toList()
              : <Widget>[];

          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );

  }
  Future<void> _pushSaved() async {
    var _myPairList=_saved;
    Set <WordPair>s= await AuthRepository.instance().getSaved();
    _myPairList=_saved.union(s);
    Navigator.of(context).push(
    MaterialPageRoute<void>(
        builder: (context)   {
            final tiles = _myPairList.map(
                  (pair) {
                return  Dismissible(
                    child:ListTile(
                    title: Text(
                    pair.asPascalCase,
                    style: _biggerFont,
                  )),
                  background: Container(
                    color: Colors.deepPurple,
                    child: Row(
                      children:const <Widget> [
                        Icon(Icons.delete,color: Colors.white,),
                        Text('Delete Suggestion',style: TextStyle(color: Colors.white),)
                      ],
                    ),
                  ),
                      secondaryBackground: Container(
                        color: Colors.deepPurple,
                        child: Row(
                          mainAxisAlignment:MainAxisAlignment.end ,
                          children:const <Widget> [
                            Icon(Icons.delete,color: Colors.white,),
                            Text('Delete Suggestion',style: TextStyle(color: Colors.white),)
                          ],
                        ),
                      ),
                      key: ValueKey<WordPair>(pair),
                      onDismissed: (DismissDirection direction) {
                        setState(() {
                          AuthRepository.instance().removepair(pair.toString());
                          setState(()=>_saved.remove(pair));
                        });
                        },
                  confirmDismiss:(DismissDirection direction)async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Delete Suggestion'),
                          content: Text(
                              'Are you sure you want to delete $pair from your saved suggestions?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Yes'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No'),
                            ),
                          ],
                        );
                      }
                    );
                  },
                );
              },
            );
            final divided = tiles.isNotEmpty
                ? ListTile.divideTiles(
              context: context,
              tiles: tiles,
            ).toList()
                : <Widget>[];
            return Scaffold(
              appBar: AppBar(
                title: const Text('Saved Suggestions'),
              ),
              body: ListView(children: divided),
            );
          },
        )
    );
  }
  void _pushLogout(){
    context.read<AuthRepository>().signOut();
    const snackBar = SnackBar(content: Text('Successfully logged out'));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    _saved.clear();
  }

  /*void _pushLogin(){
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          bool _isLoadingNotifier = false;
          void _onSignIn() async {
            _isLoadingNotifier=true;
            await context.read<AuthRepository>().signIn(emailController.text.trim(), passwordController.text.trim());
            _isLoadingNotifier=false;
            if(AuthRepository.instance().status==Status.Unauthenticated){
              const snackBar = SnackBar(content: Text('There was an error logging into the app'));
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
            }
            else{
              Navigator.pop(context);
            }
          }
          void _onSignOut() {}
          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: const Text('Login'),
            ),
            body: Container(
              padding:EdgeInsets.all(20) ,
              child: Column(
                children: [
                   const Text("Welcome to Startup Names Generators, please log in below"),
                  const  SizedBox(height: 20),
                   TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: "Email",
                    ),
                  ),
                 const  SizedBox(height: 20),
                    TextField(
                     controller: passwordController,
                     obscureText: true,
                     decoration: InputDecoration(
                      hintText: "Password",
                    ),
                  ),
                  const  SizedBox(height: 20),
                  Material(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.deepPurple,
                  child:MaterialButton(
                     minWidth: MediaQuery.of(context).size.width,
                      onPressed: !_isLoadingNotifier? _onSignIn : null,
                      child: const Text('Log in',style: TextStyle(color:Colors.white)),
                    )
                ),
                  Material(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.blue,
                      child:MaterialButton(
                        minWidth: MediaQuery.of(context).size.width,
                        onPressed: _onSignOut,
                        child: const Text('New user? Click to sign up',style: TextStyle(color:Colors.white)),
                      )
                  )
                ],
              )
            )
          );
          },
      ),

    );
  }*/
  void _loginScreen() {
    //final user = Provider.of<LogInApp>(context,listen:true);
    // bool pressed=false;
    Navigator.pushNamed(context, '/login');
  }
// #docregion RWS-var
}
// #enddocregion RWS-var

class RandomWords extends StatefulWidget {
  @override
  State<RandomWords> createState() => _RandomWordsState();
}
/*class AuthenticaionWrapper extends StatelessWidget{
  const AuthenticaionWrapper({
     Key? key,
}): super(key:key);
  @override
  Widget build(BuildContext context)
  {
    return RandomWords();
  }
}*/
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreen createState() => _LoginScreen();
}

class _LoginScreen extends State<LoginScreen> {
  var scaffoldKey = new GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    //final user = Provider.of<LogInApp>(context);
        bool _isLoadingNotifier = false;
        var _validate = true;

        TextEditingController passwordController = TextEditingController();
        TextEditingController emailController = TextEditingController();
        TextEditingController confirmController = TextEditingController();

        void _onSignIn() async {
          _isLoadingNotifier=true;
          await context.read<AuthRepository>().signIn(emailController.text.trim(), passwordController.text.trim());
          _isLoadingNotifier=false;
          if(AuthRepository.instance().status==Status.Unauthenticated){
            const snackBar = SnackBar(content: Text('There was an error logging into the app'));
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          }
          else{
            Navigator.pop(context);
          }
        }
        void _onSignUp() {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (BuildContext context) {
                return AnimatedPadding(
                  padding: MediaQuery.of(context).viewInsets,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.decelerate,
                  child: Container(
                    height: 200,
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                              'Please confirm your password below:'),
                          const SizedBox(height: 20),
                          Container(
                            width: 350,
                            child: TextField(
                              controller: confirmController,
                              obscureText: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Password',
                                errorText: _validate
                                    ? null
                                    : 'Passwords must match',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ButtonTheme(
                            minWidth: 100.0,
                            height: 35,
                            child: MaterialButton(
                                color: Colors.blue,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(18.0),
                                    side: BorderSide(color: Colors.blue)),
                                child: Text(
                                  'Confirm',
                                  style: TextStyle(fontSize: 14, color: Colors.white),
                                ),
                                onPressed: () async {
                                  if (confirmController.text == passwordController.text) {
                                    AuthRepository.instance().signUp(
                                        emailController.text, passwordController.text);
                                    Navigator.pop(context);// to login screen
                                    Navigator.pop(context);// to main screen

                                    //Navigator.pushNamed(context, '/');
                                  } else {
                                    setState(() {
                                      _validate = false;
                                      FocusScope.of(context).requestFocus(FocusNode());
                                    });
                                  }
                                }),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
            //
            //Navigator.pop(context);
  }
        return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: const Text('Login'),
            ),
            body: Container(
                padding:EdgeInsets.all(20) ,
                child: Column(
                  children: [
                    const Text("Welcome to Startup Names Generators, please log in below"),
                    const  SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: "Email",
                      ),
                    ),
                    const  SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "Password",
                      ),
                    ),
                    const  SizedBox(height: 20),
                    Material(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.deepPurple,
                        child:MaterialButton(
                          minWidth: MediaQuery.of(context).size.width,
                          onPressed: !_isLoadingNotifier? _onSignIn : null,
                          child: const Text('Log in',style: TextStyle(color:Colors.white)),
                        )
                    ),
                    const  SizedBox(height: 20),
                    Material(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.blue,
                        child:MaterialButton(
                          minWidth: MediaQuery.of(context).size.width,
                          onPressed: _onSignUp,
                          child: const Text('New user? Click to sign up',style: TextStyle(color:Colors.white)),
                        )
                    )
                  ],
                )
            )
        );
      }
}

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:english_words/english_words.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class AuthRepository with ChangeNotifier {

  FirebaseAuth _auth;
  User? _user;
  Status _status = Status.Uninitialized;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Set<WordPair> data = new Set<WordPair>();
  FirebaseStorage _storage = FirebaseStorage.instance;

  AuthRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _user = _auth.currentUser;
    _onAuthStateChanged(_user);
  }
  AuthRepository(this._auth);
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Status get status => _status;

  User? get user => _user;

  bool get isAuthenticated => status == Status.Authenticated;

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      print(e);
      _status = Status.Unauthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      data=await getSaved();
      notifyListeners();
      return true;
    } catch (e) {
      print(e);
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.Unauthenticated;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
    notifyListeners();
  }
  Future<Set<WordPair>> getSaved() async {
    Set<WordPair> s = new Set<WordPair>();
    await _firestore.collection('User').doc(_user!.uid).collection('saved').get().then((querySnapshot) {
      querySnapshot.docs.forEach((pair) {
        String First = pair.data().entries.first.value.toString();
        String Last = pair.data().entries.last.value.toString();
        s.add(WordPair(First, Last));
      });
    });
    return Future<Set<WordPair>>.value(s);
  }
  Future<void> addpair(String pair, String first, String second) async {
    if (_status == Status.Authenticated) {
      await _firestore.collection('User').doc(_user!.uid)
          .collection('saved')
          .doc(pair.toString())
          .set({'first': first, 'second': second});
    }
    data = await getSaved();
    notifyListeners();
  }

  Future<void> removepair(String pair) async {
    if (_status == Status.Authenticated) {
      await _firestore.collection('User').doc(_user!.uid).collection('saved').doc(pair.toString()).delete();
      data = await getSaved();
      notifyListeners();
    }
    notifyListeners();
  }
  Set<WordPair> getData(){
    return data;
  }
  String? getUserName() {
    return _user!.email;
  }


  Future<void> uploadNewImage(File file)async {
    await _storage
        .ref('images')
        .child(_user!.uid)
        .putFile(file);
    notifyListeners();
  }

  Future<String>
  getImageUrl() async {
    return await _storage.ref('images').child(_user!.uid).getDownloadURL();
  }
}
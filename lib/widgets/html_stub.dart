/// Stub for dart:html on mobile platforms
/// This file provides empty stubs for HTML elements used on web

// Empty stub - these classes are only used on web where dart:html is available
class AnchorElement {
  String? href;
  String? target;
  AnchorElement({this.href, this.target});
  void setAttribute(String name, String value) {}
  void click() {}
  void remove() {}
}

class _Document {
  _BodyElement? get body => null;
}

class _BodyElement {
  void append(dynamic element) {}
}

class _Navigator {
  String? get userAgent => null;
  String? get platform => null;
  String? get language => null;
}

class _Window {
  _Navigator? get navigator => null;
}

final document = _Document();
final window = _Window();


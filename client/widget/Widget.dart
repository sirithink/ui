/* Widget.dart

  History:
    Mon Jan  9 13:01:36 TST 2012, Created by tomyeh

Copyright (C) 2012 Potix Corporation. All Rights Reserved.
*/
#library("dargate:widget:Widget");

#import("dart:html");
#import("../util/Strings.dart");
#import("UiException.dart");
#import("IdSpace.dart");
#import("Skipper.dart");

/** Called after all [Widget.enterDocument_] methods are called, where
 * [topWidget] is the topmost widget that the binding starts with.
 */ 
typedef void AfterEnterDocument(Widget topWidget);

/**
 * A widget.
 */
class Widget {
  String _id = "";
  String _uuid;
  String _style = "", _wclass = "";
  Set<String> _classes;

  Widget _parent;
  Widget _firstChild, _lastChild;
  Widget _nextSibling, _prevSibling;
  int _nChild = 0;
  //The fellows. Used only if this is IdSpace
  Map<String, Widget> _fellows;
  //Virtual ID space. Used only if this is root but not IdSpace
  IdSpace _virtIS;
  bool _visible = true, _inDoc;

  Widget() {
    _classes = new Set();
    if (this is IdSpace)
      _fellows = {};
  }
  Widget.from(Map<String, Object> props): this() {
    //TODO    
  }

  /** Returns the UUID of this component, never null.
   */
  String get uuid() {
    if (_uuid == null)
      _uuid = _nextUuid();
    return _uuid;
  }
  static String _nextUuid() {
    int v = _uuidNext++;
    final StringBuffer sb = new StringBuffer("w_");
    do {
      int v2 = v % 37;
      if (v2 <= 9) sb.add(addCharCodes('0', v2));
      else sb.add(v2 == 36 ? '_': addCharCodes('a', v2 - 10));
    } while ((v ~/= 37) >= 1);
    return sb.toString();
  }
  static int _uuidNext = 0;

  /** Returns the ID of this widget, or an empty string if not assigned.
   */
  String get id() {
    return _id;
  }
  /** Sets the ID of this widget.
   */
  void set id(String id) {
    if (id == null) id = "";
    if (_id != id) {
      if (id.length > 0)
        _checkIdSpaces(this, id);
      _removeFromIdSpaces(this);
      _id = id;
      _addToIdSpace(this);
    }
  }
  /** Searches and returns the first widget that matches the given selector.
   */
  Widget query(String selector) {
    //TODO
  }
  /** Searches and returns all widgets that matches the selector.
   */
  List<Widget> queryAll(String selector) {
    //TODO
  }
  /** Returns the widget of the given ID, or null if not found.
   */
  Widget getFellow(String id) {
    var owner = spaceOwner;
    return owner._fellows[id];
  }
  /** Returns the owner of the ID space that this widget belongs to.
   * <p>A virtual [IdSpace] is used if this widget is a root but is not IdSpace.
   */
  IdSpace get spaceOwner() => _spaceOwner(this, false); //not to ignore virtual

  static IdSpace _spaceOwner(Widget wgt, bool ignoreVirtualIS) {
    Widget top;
    var p = wgt;
    do {
      if (p is IdSpace)
        return p;
      top = p;
    } while ((p = p.parent) != null);

    if (!ignoreVirtualIS) {
      if (top._virtIS == null)
        top._virtIS = new _VirtualIdSpace(top);
      return top._virtIS;
    }
  }
  /** Checks the uniqueness in ID space when changing ID. */
  static void _checkIdSpaces(Widget wgt, String newId) {
    var space = wgt.spaceOwner;
    if (space._fellows.containsKey(newId))
      throw new UiException("Not unique in the ID space of $space: $newId");

    //we have to check one level up if wgt is IdSpace (i.e., unique in two ID spaces)
    Widget parent;
    if (wgt is IdSpace && (parent = wgt.parent) != null) {
      space = parent.spaceOwner;
      if (space._fellows.containsKey(newId))
        throw new UiException("Not unique in the ID space of $space: $newId");
    }
  }
  //Add the given widget to the ID space
  static void _addToIdSpace(Widget wgt){
    String id = wgt.id;
    if (id.length == 0)
      return;

    var space = wgt.spaceOwner;
    space._fellows[id] = wgt;

    //we have to put it one level up if wgt is IdSpace (i.e., unique in two ID spaces)
    Widget parent;
    if (wgt is IdSpace && (parent = wgt.parent) != null) {
      space = parent.spaceOwner;
      space._fellows[id] = wgt;
    }
  }
  //Add the given widget and all its children to the ID space
  static void _addToIdSpaceDown(Widget wgt, var space) {
    if (wgt is IdSpace) {
      if (space == null) //the top invocation made by insertBefore called
        _addToIdSpace(wgt);
      return; //done
    }

    if (space == null)
      space = wgt.spaceOwner;

    var id = wgt.id;
    if (id.length > 0)
      space._fellows[id] = wgt;

    for  (wgt = wgt.firstChild; wgt != null; wgt = wgt.nextSibling)
      _addToIdSpaceDown(wgt, space);
  }
  static void _removeFromIdSpaces(Widget wgt) {
    String id = wgt.id;
    if (id.length == 0)
      return;

    var space = wgt.spaceOwner;
    space._fellows.remove(id);

    //we have to put it one level up if wgt is IdSpace (i.e., unique in two ID spaces)
    Widget parent;
    if (wgt is IdSpace && (parent = wgt.parent) != null) {
      space = parent.spaceOwner;
      space._fellows.remove(id);
    }
  }

  /** Returns the parent, or null if this widget does not have any parent.
   */
  Widget get parent() => _parent;
  /** Returns the first child, or null if this widget has no child at all.
   */
  Widget get firstChild() => _firstChild;
  /** Returns the last child, or null if this widget has no child at all.
   */
  Widget get lastChild() => _lastChild;
  /** Returns the next sibling, or null if this widget is the last sibling.
   */
  Widget get nextSibling() => _nextSibling;
  /** Returns the previous sibling, or null if this widget is the previous sibling.
   */
  Widget get previousSibling() => _prevSibling;

  /** Callback when a child has been added.
   * <p>Default: does nothing.
   */
  void onChildAdd_(Widget child) {}
  /** Callback when a child has been removed.
   * <p>Default: does nothing.
   */
  void onChildRemove_(Widget child) {}

  /** Appends a child to the end of all children.
   * It calls [insertBefore] with refChild to be null, so the 
   * subclass needs to override [insertBefore] if necessary.
   */
  Widget appendChild(Widget child) => insertBefore(child, null);
  /** Inserts a child before the reference child.
   * If the given widget is always a child, its position among children
   * will be changed depending on [refChild].
   * <p>Notice that [appendChild] will call back this methid, so the subclass
   * need only to override this method, if necessary.
   */
  Widget insertBefore(Widget child, Widget refChild) {
    for (Widget p = this; p != null; p = p.parent)
      if (p === child)
        throw new UiException("$child is an ancestor of $this");
    if (refChild != null && refChild.parent !== this)
      refChild = null;

    if (child.parent === this) {
      if (child.nextSibling !== refChild) { //move?
        _unlink(this, child);
        _link(this, child, refChild);
      }
      return this; //done
    }

    _link(this, child, refChild);
    child._parent = this;
    ++_nChild;

    _addToIdSpaceDown(child, null);

    onChildAdd_(child);
    return this;
  }
  /** Removes a child.
   * It returns true if the child is removed succefully, or false if it is
   * a child.
   */
  bool removeChild(Widget child) {
    if (child.parent !== this)
      return false;

    _unlink(this, child);
    child._parent = null;
    --_nChild;

    onChildRemove_(child);
    return true;
  }
  static void _link(Widget wgt, Widget child, Widget refChild) {
    if (refChild == null) {
      Widget p = wgt._lastChild;
      if (p != null) {
        p._nextSibling = child;
        child._prevSibling = p;
        wgt._lastChild = child;
      } else {
        wgt._firstChild = wgt._lastChild = child;
      }
    } else {
      Widget p = refChild._prevSibling;
      if (p != null) {
        child._prevSibling = p;
        p._nextSibling = child;
      } else {
        wgt._firstChild = child;
      }

      refChild._prevSibling = child;
      child._nextSibling = refChild;
    }
  }
  static void _unlink(Widget wgt, Widget child) {
    var p = child._prevSibling, n = child._nextSibling;
    if (p != null) p._nextSibling = n;
    else wgt._firstChild = n;
    if (n != null) n._prevSibling = p;
    else wgt._lastChild = p;
    child._nextSibling = child._prevSibling = child._parent = null;
  }

  /** Returns the DOM element associated with this widget.
   * This method returns null if this widget is not bound the DOM,
   * or it doesn't have the associate element.
   * <p>To retrieve a child element, use the [getNode] method instead.
   */
  Element get node() => _inDoc ? document.query('#' + uuid): null;
      //no need to cache since IE6 not supported
  /** Returns the child element of the given sub-ID.
   * This method assumes the ID of the child element the concatenation of
   * uuid, dash ('-'), and subId.
   */
  Element getNode(String subId) =>
    _inDoc ? document.query(subId != null && subId.length > 0 ?
           '#' + uuid + '-' + subId: '#' + uuid): null;
  /** Returns if this widget has been added to the document.
   */
  bool get isInDocument() => _inDoc;

  /** Replaces the given DOM element with
   * the HTML fragment generated by this widget (with [redraw]).
   * <p>This method can be called only if this widget has no parent.
   */
  void addToDocument(Element node,
  [bool outer=false, bool inner=false, Element before]) {
    if (parent != null)
      throw new UiException("Only root widgets are allowed; not $this");
  
    var out = new StringBuffer();
    redraw(out, null);
    out = out.toString();
    if (outer) {
      Element p = node.parent, nxt = node.nextElementSibling;
      node.remove();
      p.insertBefore(new Element.html(out), nxt);
    } else if (inner) {
      node.innerHTML = out;
    } else if (before != null) {
      node.insertBefore(new Element.html(out), before);
    } else {
      node.nodes.add(new Element.html(out));
    }
    _enterDocument(null);
  }
  /** Removes the widget from the document.
   * All of descendant widgets are removed too.
   * <p>This method can be called only if this widget has no parent.
   */
  void removeFromDocument() {
    if (parent != null)
      throw new UiException("Only root widgets are allowed; not $this");
  
    _exitDocument(null);
    node.remove();
  }
  /** Binds the widget.
   */
  void _enterDocument(Skipper skipper) {
    List<AfterEnterDocument> afters = [];

    enterDocument_(skipper, afters);

    for (final AfterEnterDocument call in afters)
      call(this);
  }
  /** Unbinds the widget.
   */
  void _exitDocument(Skipper skipper) {
    exitDocument_(skipper);
  }
  /** Callback when this widget is attached to the document.
   * <p>Default: invoke [enterDocument_] for each child.
   * <p>Subclass shall call back this method if it overrides this method. 
   */
  void enterDocument_(Skipper skipper, List<AfterEnterDocument> afters) {
    _inDoc = true;
    for (Widget child = firstChild; child != null; child = child.nextSibling)
      child.enterDocument_(skipper, afters);
  }
  /** Callback when this widget is detached from the document.
   * <p>Default: invoke [exitDocument_] for each child.
   * <p>Subclass shall call back this method if it overrides this method. 
   */
  void exitDocument_(Skipper skipper) {
    _inDoc = false;
    for (Widget child = firstChild; child != null; child = child.nextSibling)
      child.exitDocument_(skipper);
  }
  /** Generates the HTML fragment for this widget and its descendants.
   */
  void redraw(StringBuffer out, Skipper skipper) {
    for (Widget child = firstChild; child != null; child = child.nextSibling)
      child.redraw(out, null); //don't pass skipper to child
  }

  /** Returns if this widget is visible.
   */
  bool get visible() => _visible;
  /** Sets if this widget is visible.
   */
  void set visible(bool visible) {
    _visible = visible;
    Element n = node;
    if (n != null) n.style.transform = domStyle_();
  }
  /** Retuns the CSS style.
   */
  String get style() => _style;
  /** Sets the CSS style.
   * Notice that it shall not include <code>display</code>, which
   * is controlled by [visible].
   */
  void set style(String style) {
    _style = style != null ? style: "";
    Element n = node;
    if (n != null) n.style.transform = domStyle_();
  }
  /** Retuns the widget class.
   */
  String get wclass() => _wclass;
  /** Sets the widget class.
   * <p>Default: empty, but an implementation usually provides a default
   * class, such as <code>w-label</code>. It is used to provide
   * the default look for this widget. If wclass is changed, all the default
   * styles are gone.
   */
  void set wclass(String wclass) {
    _wclass = wclass != null ? wclass: "";
    Element n = node;
    if (n != null) {
      Set<String> clses = new Set();
      if (!_wclass.isEmpty())
        clses.add(_wclass);
      clses.addAll(_classes);
      n.classes = clses; 
    }
  }
  /** Returns a readonly list of the additional style classes.
   */
  Set<String> get classes() => _classes;
  /** Adds the give style class.
   */
  void addClass(String className) {
    classes.add(className);
    Element n = node;
    if (n != null) n.classes.add(className);
  }
  /** Removes the give style class.
   */
  void removeClass(String className) {
    classes.remove(className);
    Element n = node;
    if (n != null) n.classes.remove(className);
  }

  /** Ouptuts all attributes used for the DOM element of this widget.
   */
  String domAttrs_([noId=false, noStyle=false, noClass=false]) {
    final StringBuffer sb = new StringBuffer();
    String s;
    if (!noId && !(s = uuid).isEmpty())
      sb.add(' id="').add(s).add('"');
    if (!noStyle && !(s = domStyle_()).isEmpty())
      sb.add(' style="').add(s).add('"');
    if (!noClass && !(s = domClass_()).isEmpty())
      sb.add(' class="').add(s).add('"');
    return sb.toString();
  }
  /** Outputs the style used for the DOM element of this widget.
   */
  String domStyle_([noDisplay=false]) {
    return noDisplay || _visible ? _style: "display:none;$_style";
  }
  /** Outputs the class used for the DOM element of this widget.
   */
  String domClass_([noWclass=false, noClass=false]) {
    final StringBuffer sb = new StringBuffer();
    if (!noWclass)
      sb.add(_wclass);
    if (!noClass)
      for (final String cls in _classes) {
        if (!sb.isEmpty()) sb.add(' ');
        sb.add(cls);
      }
    return sb.toString();
  }
}

/** A virtual ID space. Used only internally.
 */
class _VirtualIdSpace implements IdSpace {
  Widget _owner;
  Map<String, Widget> _fellows;

  _VirtualIdSpace(this._owner): _fellows = {};
  
  Widget query(String selector) => _owner.query(selector);
  List<Widget> queryAll(String selector) => _owner.queryAll(selector);
  Widget getFellow(String id) => _fellows[id];
}

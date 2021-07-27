part of vcl;

class _mouseHit
{
  final Element elem;
  final int x;
  final int y;
  final int type;
  final Element target;
  _mouseHit._(this.elem, this.x, this.y, this.type, this.target);

  static _mouseHit? fromEvent(MouseEvent event)
  {
    Element elem = Windows.ElemFromEvent(event);

    TPoint pt = TPoint(event.client.x.round(), event.client.y.round());
    int type = toIntDef(Windows.SendElementMessage(elem, WM_NCHITTEST, null, pt), Windows.HTNOWHERE);
    if(type!=Windows.HTNOWHERE)
    {
      Rectangle rect = elem.getBoundingClientRect();
      return _mouseHit._(elem, pt.x-rect.left.truncate(), pt.y-rect.top.truncate(), type, event.target as Element);
    }
    return null;
  }

  String toString()
  {
    return 'elem: $elem, x: $x, y: $y, type: $type, target: $target';
  }
}


abstract class Windows
{
  static HWND?    _activeWindow;
  static Element? _downElement;
  static Element? _capture;
  static final    _mousePos = TPoint(0, 0);
  static final    _keyPressed = Set<int>(); // pressed keys

  // dispatch table
  static dynamic _doBlur;
  static dynamic _doCopy;
  static dynamic _doCut;
  static dynamic _doDblClick;
  static dynamic _doFocus;
  static dynamic _doKeyDown;
  static dynamic _doKeyPress;
  static dynamic _doKeyUp;
  static dynamic _doMouseDown;
  static dynamic _doMouseMove;
  static dynamic _doMouseOver;
  static dynamic _doMouseOut;
  static dynamic _doMouseUp;
  static dynamic _doMouseWhell;
  static dynamic _doPaste;
  static dynamic _doTouchStart;
  static dynamic _doTouchEnd;
  static dynamic _doTouchMove;

  static bool _active = false;

  static void _start()
  {
    if(_active)
      return;

    _run();

    void idle(deadline)
    {

      if(_application != null)
        _application!.Idle(); 

      if(_active)
        window.requestIdleCallback(idle);
    }
    window.requestIdleCallback(idle);

  }

  static void _run()
  {
    if(_active)
      return;
    _active = true;

    int? hitType;
    Point? downPos;


    dynamic doFocus(Event _event)
    {
  
      if(!(_event is FocusEvent))
        return;
      FocusEvent event = _event;

      if(event.relatedTarget!=null)
          return;

      Element? elem = ElemByChild(event.target as Element);

      if(elem != null)
      {
        SendElementMessage(elem, CM_SETFOCUS, null, null);
        SendElementMessage(elem, WM_SETFOCUS, null, null);
      }
    }

    dynamic doBlur(Event _event)
    {

      if(!(_event is FocusEvent))
        return;
      FocusEvent event = _event;

      if(event.relatedTarget==null)
      {

        TControl? ctrl = SendElementMessage(_downElement, CM_GETINSTANCE, 0, 0);
        if(ctrl != null && (!(ctrl is TWinControl) || ctrl.TabStop == false))
        {
          TCustomForm? form = ctrl is TCustomForm? ctrl : ctrl.ParentForm;
          if(form != null)
          {
            if(form.Active)
              form.SetWindowFocus();
            else
              form.SetActive(true);
            return;
          }

        }
      }

      if(event.target != null)
      {
        var tControl = FindElementControl(event.target as Element);
        var rControl = FindElementControl(event.relatedTarget as Element?);
        if(tControl!=null && (tControl == rControl || event.relatedTarget==null))
        { // элементы одного контрола
          Windows.SetFocus(tControl.Handle);
          return;
        }
      }

      Element? elem = ElemByChild(event.target as Element);
      if(elem != null)
      {
        Element? fElem = ElemByChild(event.relatedTarget as Element);

        if(fElem!=elem)
        {
          SendElementMessage(elem, WM_KILLFOCUS, fElem, null);

          if(fElem!=null)
          {
            SendElementMessage(fElem, CM_SETFOCUS, elem, null);
            SendElementMessage(fElem, WM_SETFOCUS, elem, null);
          }
        }
      }
    }

    dynamic doMouseEvent(MouseEvent event, List<MESSAGE> types)
    {
      if(event.button>=types.length)
        return null;

      Element? elem = ElemFromEvent(event);


      TPoint clientPos;
      var hWnd = HWND.findWindow(elem);
      if(hWnd==null)
      {
        TRect r= elem.borderRect;
        int px = event.client.x.toInt()-r.left;
        int py = event.client.y.toInt()-r.top;
        clientPos = TPoint(px, py);
      }
      else
      {
        clientPos = TPoint(event.client.x.toInt(), event.client.y.toInt());
        Windows.ScreenToClient(hWnd, clientPos);
      }

      SendElementMessage(elem, types[event.button], MouseEventToShiftState(event), clientPos);
    }

    dynamic doMouseMove(Event _event)
    {
      MouseEvent event = _event as MouseEvent;
      _mousePos.x = event.client.x.toInt();
      _mousePos.y = event.client.y.toInt();

      if(_capture != null && downPos!=null && hitType!=Windows.HTCLIENT)
      {
        num dx = event.client.x - downPos!.x;
        num dy = event.client.y - downPos!.y;
        var hWnd = _capture==null? null : HWND.findWindow(_capture!);
        if(dx+dy==0 || hWnd==null)
          return;
        downPos = event.client;


        Rectangle rect = hWnd.handle.offset;
        switch(hitType)
        {
          case Windows.HTBOTTOMLEFT:
            Windows.SetWindowPos(hWnd, null, (rect.left+dx).toInt(), null, (rect.width-dx).toInt(), (rect.height+dy).toInt(), 0);
            break;
          case Windows.HTBOTTOMRIGHT:
            Windows.SetWindowPos(hWnd, null, null, null, (rect.width+dx).toInt(), (rect.height+dy).toInt(), 0);
            break;
          case Windows.HTTOPLEFT:
            Windows.SetWindowPos(hWnd, null, (rect.left+dx).toInt(), (rect.top+dy).toInt(), (rect.width-dx).toInt(), (rect.height-dy).toInt(), 0);
            break;
          case Windows.HTTOPRIGHT:
            Windows.SetWindowPos(hWnd, null, null, (rect.top+dy).toInt(), (rect.width+dx).toInt(), (rect.height-dy).toInt(), 0);
            break;
          case Windows.HTTOP:
            Windows.SetWindowPos(hWnd, null, null, (rect.top+dy).toInt(), null, (rect.height-dy).toInt(), 0);
            break;
          case Windows.HTLEFT:
            Windows.SetWindowPos(hWnd, null, (rect.left+dx).toInt(), null, (rect.width-dx).toInt(), null, 0);
            break;
          case Windows.HTRIGHT:
            Windows.SetWindowPos(hWnd, null, null, null, (rect.width+dx).toInt(), null, 0);
            break;
          case Windows.HTBOTTOM:
            Windows.SetWindowPos(hWnd, null, null, null, null, (rect.height+dy).toInt(), 0);
            break;
          case Windows.HTCAPTION:
            Windows.SetWindowPos(hWnd, null, (rect.left+dx).toInt(), (rect.top+dy).toInt(), null, null, 0);
            break;

          default:
            return;
        }

      }

      doMouseEvent(_event, [WM_MOUSEMOVE, WM_MOUSEMOVE, WM_MOUSEMOVE]);
    }

    dynamic doMouseDown(Event _event)
    {
      _capture = null;
      downPos = null;
      _mouseHit? mh = _mouseHit.fromEvent(_event as MouseEvent);

      if(mh==null)
      {
        doMouseEvent(_event, [WM_LBUTTONDOWN, WM_MBUTTONDOWN, WM_RBUTTONDOWN]);
        if(_event.target is DivElement || _event.target is LabelElement)
          _event.preventDefault(); 
        return;
      }

      MouseEvent event = _event;
      if(event.button == 0) // hittest
      {
        downPos = event.client;
        hitType = mh.type;
        _capture = mh.type==0? null : mh.elem;
      }
      MESSAGE msg = [WM_LBUTTONDOWN, WM_MBUTTONDOWN, WM_RBUTTONDOWN][event.button];
      SendElementMessage(mh.elem, msg, MouseEventToShiftState(event), TPoint(mh.x, mh.y));

      if(document.activeElement!=null)
      {

        var ctrl = FindElementControl(mh.elem);
        if(ctrl!=null)
        {
          if(ctrl is TCustomForm || /*ctrl==FindControl(document.activeElement) ||*/ !ctrl.CanFocus())
            _event.preventDefault();
        }
      }
      
    }

    dynamic doMouseUp(Event _event)
    {

      MouseEvent event = _event as MouseEvent;
      _mousePos.x = event.client.x.toInt();
      _mousePos.y = event.client.y.toInt();

      doMouseEvent(_event, [WM_LBUTTONUP, WM_MBUTTONUP, WM_RBUTTONUP]);

      _capture = null;
      hitType = 0;

    }

    dynamic doDblClick(Event _event)
    {
      doMouseEvent(_event as MouseEvent, [WM_LBUTTONDBLCLK, WM_MBUTTONDBLCLK, WM_RBUTTONDBLCLK]);
    }

    dynamic doMouseOver(Event _event)
    {

    }

    dynamic doMouseOut(Event _event)
    {

    }

    dynamic doMouseWhell(Event _event)
    {
      WheelEvent event = _event as WheelEvent;
      Element elem = ElemFromEvent(event);
      //if(elem == null)
      //  return;
      TShiftState Shift = TShiftState();
      if(event.ctrlKey)
        Shift << ShiftStates.Ctrl;
      if(event.altKey)
        Shift << ShiftStates.Alt;
      if(event.shiftKey)
        Shift << ShiftStates.Shift;

      TRect r= elem.contentRect;
      int px = event.client.x.toInt()-r.left;
      int py = event.client.y.toInt()-r.top;

      SendElementMessage(elem, WM_MOUSEWHEEL, TWheelInfo(-event.deltaY.toInt(), Shift), TPoint(px, py));
      return false;
    }

    dynamic doCopy(Event _event)
    {
      ClipboardEvent event = _event as ClipboardEvent;
      Element elem = ElemFromEvent(event);
      int state = toIntDef(SendElementMessage(elem, WM_COPY, event.clipboardData, event), 0);
      if(state!=0)
        _event.preventDefault();
    }

    dynamic doCut(Event _event)
    {
      ClipboardEvent event = _event as ClipboardEvent;
      Element elem = ElemFromEvent(event);
      int state = toIntDef(SendElementMessage(elem, WM_CUT, event.clipboardData, event), 0);
      if(state!=0)
        _event.preventDefault();
    }

    dynamic doPaste(Event _event)
    {
      ClipboardEvent event = _event as ClipboardEvent;
      Element elem = ElemFromEvent(event);
      int state = toIntDef(SendElementMessage(elem, WM_PASTE, event.clipboardData, event),0);
      if(state!=0)
        _event.preventDefault();
    }

    int _touchx = 0;
    int _touchy = 0;

    dynamic doTouchStart(Event _event)
    {
      TouchEvent event = _event as TouchEvent;
      Touch t = event.changedTouches![0];

      _touchx=t.client.x.toInt();
      _touchy=t.client.y.toInt();
    }

    dynamic doTouchEnd(Event _event) {
    }

    dynamic doTouchMove(Event _event)
    {
      TouchEvent event = _event as TouchEvent;
      Touch t = event.changedTouches![0];
      int dx = t.client.x.toInt() - _touchx;
      int dy = t.client.y.toInt() - _touchy;
      _touchx = t.client.x.toInt();
      _touchy = t.client.y.toInt();

      Element? elem = ElemByChild(event.target as Element);
      if(elem == null)
        return;

      TShiftState Shift = TShiftState();
      SendElementMessage(elem, WM_MOUSEWHEEL, TWheelInfo(-dy*10, Shift), TPoint(0, 0));
    }

    dynamic doKeyDown(Event _event)
    {
      KeyboardEvent event = _event as KeyboardEvent;
      _keyPressed.add(event.keyCode);

      if(event.keyCode==Windows.VK_TAB && Screen.ActiveCustomForm!=null)
      { 
        TCustomForm? form = Screen.ActiveCustomForm;
        TControl? ctrl = form==null? null : form.FindNextControl(form.ActiveControl, true, true, false);
        if(ctrl==null || ctrl==form!.ActiveControl)
        {
          event.preventDefault();
          return true;
        }
      }
      Element? elem = ElemByChild(event.target as Element);

      if(elem == null)
        return true;

      bool Result = toBoolDef(SendElementMessage(elem, WM_KEYDOWN, event.keyCode, KeyboardEventToShiftState(event)), true);
      if(Result == false)
      {
        event.preventDefault();
      }
      
    }

    dynamic doKeyPress(Event _event)
    {
      KeyboardEvent event = _event as KeyboardEvent;
      if(event.code == "")
        return;
      Element? elem = ElemByChild(event.target as Element);
      if(elem == null)
        return;

      bool Result = toBoolDef(SendElementMessage(elem, WM_CHAR, event.keyCode, KeyboardEventToShiftState(event)), true);
      if(Result == false)
        event.preventDefault();


    }

    dynamic doKeyUp(Event _event)
    {
      KeyboardEvent event = _event as KeyboardEvent;
      _keyPressed.remove(event.keyCode);

      Element? elem = ElemByChild(event.target as Element);

      if(elem == null)
        return true;

      bool Result = toBoolDef(SendElementMessage(elem, WM_KEYUP, event.keyCode, KeyboardEventToShiftState(event)), true);
      if(Result == false)
        event.preventDefault();

    }



    window.addEventListener('blur',       doBlur,       true); _doBlur = doBlur;
    window.addEventListener('copy',       doCopy,       true); _doCopy = doCopy;
    window.addEventListener('cut',        doCut,        true); _doCut = doCut;
    window.addEventListener('dblclick',   doDblClick,   true); _doDblClick = doDblClick;
    window.addEventListener('focus',      doFocus,      true); _doFocus = doFocus;
    window.addEventListener('keydown',    doKeyDown,    true); _doKeyDown = doKeyDown;
    window.addEventListener('keypress',   doKeyPress,   true); _doKeyPress = doKeyPress;
    window.addEventListener('keyup',      doKeyUp,      true); _doKeyUp = doKeyUp;
    window.addEventListener('mousedown',  doMouseDown,  true); _doMouseDown = doMouseDown;
    window.addEventListener('mousemove',  doMouseMove,  true); _doMouseMove = doMouseMove;
    window.addEventListener('mouseover',  doMouseOver,  true); _doMouseOver = doMouseOver;
    window.addEventListener('mouseout',   doMouseOut,   true); _doMouseOut = doMouseOut;
    window.addEventListener('mouseup',    doMouseUp,    true); _doMouseUp = doMouseUp;
    window.addEventListener('mousewheel', doMouseWhell, true); _doMouseWhell = doMouseWhell;
    window.addEventListener('paste',      doPaste,      true); _doPaste = doPaste;
    window.addEventListener('touchstart', doTouchStart, true); _doTouchStart = doTouchStart;
    window.addEventListener('touchmove',  doTouchMove,  true); _doTouchMove = doTouchMove;
    window.addEventListener('touchend',   doTouchEnd,   true); _doTouchEnd = doTouchEnd;


  }

  static void _stop()
  {
    if(!_active)
      return;

    _doBlur.cancel();
    _doCopy.cancel();
    _doDblClick.cancel();
    _doFocus.cancel();
    _doKeyDown.cancel();
    _doKeyPress.cancel();
    _doKeyUp.cancel();
    _doMouseDown.cancel();
    _doMouseMove.cancel();
    _doMouseOver.cancel();
    _doMouseOut.cancel();
    _doMouseUp.cancel();
    _doMouseWhell.cancel();
    _doPaste.cancel();
    _doTouchStart.cancel();
    _doTouchMove.cancel();
    _doTouchEnd.cancel();


    _active = false;
  }

  static Element? ElemByChild(Element _elem)
  {
    Element? elem = _elem;
    if(HWND._elements.containsKey(elem))
      return elem;

    HWND? sub = HWND._subElements[elem];
    if(sub == null)
    {
      while(elem != null)
      {
        if(elem is TableElement)
        {
          HWND? hwnd = HWND._subElements[elem];
          elem = hwnd==null? null : hwnd.handle;
          break;
        }
        elem = elem.parent;
      }
    }

    return sub==null? null : sub.handle;

  }

  static dynamic SendElementMessage(Element? elem, MESSAGE msg, [dynamic wParam=null, dynamic lParam=null])
  {
    if(elem == null)
      return null;

    
    var hWnd = HWND.findWindow(elem);
    if(hWnd==null)
    {
      TMessage Message = TMessage(msg);
      Message.WParam=wParam;
      Message.LParam=lParam;

      _default_element_proc(elem, Message);
      return Message.Result;
    }

    return SendMessage(hWnd, msg, wParam, lParam);
  }

  static Element ElemFromEvent(Event event)
  {
    if(_capture!=null)
      return _capture!;

    HWND? hwnd = HWND.findWindow(event.target as Element);
    return hwnd==null? event.target as Element : hwnd.handle;


  }

  static String _sysFontFamily = '"Arial", serif;';
  static String get sysFontFamily => _sysFontFamily;

  static int _sysFontSize = 10;
  static int get sysFontSize => _sysFontSize;





  static var _iState = false;
  static var iWnd = Map<HWND, TRect?>();

  static void InvalidateRect(HWND hwnd, TRect? rect, bool bErase)
  {

    iWnd[hwnd] = rect;

    if(_iState == true)
      return;

    Future<void> waiter() async {};

    _iState = true;

    waiter().then((val)
    {
      if(_iState==true)
      {
        var tmp = iWnd;
        Windows.iWnd = Map<HWND, TRect?>();
        _iState=false;

        tmp.forEach((hwnd, rect)
        {
          // to do: invalidate rect
          iWnd.remove(hwnd);
          SendMessage(hwnd, WM_PAINT, null, null);

        });
      }
    });
  }

  static int GetTickCount()
  {
    return DateTime.now().millisecondsSinceEpoch;
  }


  static TShiftState MouseEventToShiftState(MouseEvent event)
  {
    var shift = TShiftState();
    if(event.altKey)    shift << ShiftStates.Alt;
    if(event.ctrlKey)   shift << ShiftStates.Ctrl;
    if(event.shiftKey)  shift << ShiftStates.Shift;
    if((event.buttons! & 0x01) == 0x01) shift << ShiftStates.Left;
    if((event.buttons! & 0x02) == 0x02) shift << ShiftStates.Right;
    if((event.buttons! & 0x04) == 0x04) shift << ShiftStates.Middle;
    return shift;
  }

  static TShiftState KeyboardEventToShiftState(KeyboardEvent event)
  {
    var shift = TShiftState();
    if(event.altKey)    shift << ShiftStates.Alt;
    if(event.ctrlKey)   shift << ShiftStates.Ctrl;
    if(event.shiftKey)  shift << ShiftStates.Shift;
    return shift;
  }

  static void SelectFont(HWND hWnd, TFont? font)
  { 
    Element elem = hWnd.handle;
    CssStyleDeclaration css = elem.style;
    css.fontSize = (font==null)? "" : "${font.Size}pt";
    css.color = (font==null)? "" : font.Color.html;
    css.fontWeight = (font==null)? "" : (font.Bold? "bold" : "normal");
    css.fontStyle = (font==null)? "" : (font.Italic? "italic" : "normal");
  }

  static IsFocused(HWND hwnd)
  {
    Element? f = document.activeElement;
    while(f!=null)
    {
      if(f==hwnd.handle)
        return true;
      f=f.parent;
    }
    return false;
  }

  static SetCursor(TCursor cursor)
  {
    document.body!.style.cursor = cursor.name;
  }


  /* Font Weights */
  static const int FW_DONTCARE         = 0;
  static const int FW_THIN             = 100;
  static const int FW_EXTRALIGHT       = 200;
  static const int FW_LIGHT            = 300;
  static const int FW_NORMAL           = 400;
  static const int FW_MEDIUM           = 500;
  static const int FW_SEMIBOLD         = 600;
  static const int FW_BOLD             = 700;
  static const int FW_EXTRABOLD        = 800;
  static const int FW_HEAVY            = 900;

  /*   S P O O L E R   */

  /* Device Technologies */
  static const int DT_PLOTTER         = 0;  // Vector plotter
  static const int DT_RASDISPLAY      = 1;  // Raster display
  static const int DT_RASPRINTER      = 2;  // Raster printer
  static const int DT_RASCAMERA       = 3;  // Raster camera
  static const int DT_CHARSTREAM      = 4;  // Character-stream, PLP
  static const int DT_METAFILE        = 5;  // Metafile, VDM
  static const int DT_DISPFILE        = 6;  // Display-file

  /* Device Orientation */
  static const int DO_PORTRAIT        = 0;
  static const int DO_LANDSCAPE       = 1;
  static const int DO_IPORTRAIT       = 2;
  static const int DO_ILANDSCAPE      = 3;


  static const int DMPAPER_LETTER              =  1;  // Letter 8 1/2 x 11 in
  static const int DMPAPER_LETTERSMALL         =  2;  // Letter Small 8 1/2 x 11 in
  static const int DMPAPER_TABLOID             =  3;  // Tabloid 11 x 17 in
  static const int DMPAPER_LEDGER              =  4;  // Ledger 17 x 11 in
  static const int DMPAPER_LEGAL               =  5;  // Legal 8 1/2 x 14 in
  static const int DMPAPER_STATEMENT           =  6;  // Statement 5 1/2 x 8 1/2 in
  static const int DMPAPER_EXECUTIVE           =  7;  // Executive 7 1/4 x 10 1/2 in
  static const int DMPAPER_A3                  =  8;  // A3 297 x 420 mm
  static const int DMPAPER_A4                  =  9;  // A4 210 x 297 mm
  static const int DMPAPER_A4SMALL             = 10;  // A4 Small 210 x 297 mm              
  static const int DMPAPER_A5                  = 11;  // A5 148 x 210 mm                    
  static const int DMPAPER_B4                  = 12;  // B4 (JIS) 250 x 354                 
  static const int DMPAPER_B5                  = 13;  // B5 (JIS) 182 x 257 mm              
  static const int DMPAPER_FOLIO               = 14;  // Folio 8 1/2 x 13 in                
  static const int DMPAPER_QUARTO              = 15;  // Quarto 215 x 275 mm                
  static const int DMPAPER_10X14               = 16;  // 10x14 in                           
  static const int DMPAPER_11X17               = 17;  // 11x17 in                           
  static const int DMPAPER_NOTE                = 18;  // Note 8 1/2 x 11 in                 
  static const int DMPAPER_ENV_9               = 19;  // Envelope #9 3 7/8 x 8 7/8          
  static const int DMPAPER_ENV_10              = 20;  // Envelope #10 4 1/8 x 9 1/2         
  static const int DMPAPER_ENV_11              = 21;  // Envelope #11 4 1/2 x 10 3/8        
  static const int DMPAPER_ENV_12              = 22;  // Envelope #12 4 \276 x 11           
  static const int DMPAPER_ENV_14              = 23;  // Envelope #14 5 x 11 1/2            
  static const int DMPAPER_CSHEET              = 24;  // C size sheet                       
  static const int DMPAPER_DSHEET              = 25;  // D size sheet                       
  static const int DMPAPER_ESHEET              = 26;  // E size sheet                       
  static const int DMPAPER_ENV_DL              = 27;  // Envelope DL 110 x 220mm            
  static const int DMPAPER_ENV_C5              = 28;  // Envelope C5 162 x 229 mm           
  static const int DMPAPER_ENV_C3              = 29;  // Envelope C3  324 x 458 mm          
  static const int DMPAPER_ENV_C4              = 30;  // Envelope C4  229 x 324 mm          
  static const int DMPAPER_ENV_C6              = 31;  // Envelope C6  114 x 162 mm          
  static const int DMPAPER_ENV_C65             = 32;  // Envelope C65 114 x 229 mm          
  static const int DMPAPER_ENV_B4              = 33;  // Envelope B4  250 x 353 mm          
  static const int DMPAPER_ENV_B5              = 34;  // Envelope B5  176 x 250 mm          
  static const int DMPAPER_ENV_B6              = 35;  // Envelope B6  176 x 125 mm          
  static const int DMPAPER_ENV_ITALY           = 36;  // Envelope 110 x 230 mm              
  static const int DMPAPER_ENV_MONARCH         = 37;  // Envelope Monarch 3.875 x 7.5 in    
  static const int DMPAPER_ENV_PERSONAL        = 38;  // 6 3/4 Envelope 3 5/8 x 6 1/2 in    
  static const int DMPAPER_FANFOLD_US          = 39;  // US Std Fanfold 14 7/8 x 11 in      
  static const int DMPAPER_FANFOLD_STD_GERMAN  = 40;  // German Std Fanfold 8 1/2 x 12 in   
  static const int DMPAPER_FANFOLD_LGL_GERMAN  = 41;  // German Legal Fanfold 8 1/2 x 13 in 

  static TSize? GetPaperSize(int PaperFormat)
  {
    switch(PaperFormat)
    {
      case DMPAPER_LETTER:             return TSize(21590, 27940);
      case DMPAPER_LETTERSMALL:        return TSize(21590, 27940);
      case DMPAPER_TABLOID:            return TSize(27940, 43180);
      case DMPAPER_LEDGER:             return TSize(43180, 27940);
      case DMPAPER_LEGAL:              return TSize(21590, 35560);
      case DMPAPER_STATEMENT:          return TSize(13970, 21590);
      case DMPAPER_EXECUTIVE:          return TSize(18415, 26670);
      case DMPAPER_A3:                 return TSize(29700, 42000);
      case DMPAPER_A4:                 return TSize(21000, 29700);
      case DMPAPER_A4SMALL:            return TSize(21000, 29700);
      case DMPAPER_A5:                 return TSize(14800, 21000);
      case DMPAPER_B4:                 return TSize(25000, 35400);
      case DMPAPER_B5:                 return TSize(18200, 25700);
      case DMPAPER_FOLIO:              return TSize(21590, 33020);
      case DMPAPER_QUARTO:             return TSize(21500, 27500);
      case DMPAPER_10X14:              return TSize(25400, 35560);
      case DMPAPER_11X17:              return TSize(27940, 43180);
      case DMPAPER_NOTE:               return TSize(21590, 27940);
      case DMPAPER_ENV_9:              return TSize( 9843, 22543);
      case DMPAPER_ENV_10:             return TSize(10478, 24130);
      case DMPAPER_ENV_11:             return TSize(11430, 26353);
      case DMPAPER_ENV_12:             return TSize(12065, 27940);
      case DMPAPER_ENV_14:             return TSize(12700, 29210);
      case DMPAPER_CSHEET:             return TSize(43180, 55880);
      case DMPAPER_DSHEET:             return TSize(55880, 86360);
      case DMPAPER_ESHEET:             return TSize(86360, 111760);
      case DMPAPER_ENV_DL:             return TSize(11000, 22000);
      case DMPAPER_ENV_C5:             return TSize(16200, 22900);
      case DMPAPER_ENV_C3:             return TSize(32400, 45800);
      case DMPAPER_ENV_C4:             return TSize(22900, 32400);
      case DMPAPER_ENV_C6:             return TSize(11400, 16200);
      case DMPAPER_ENV_C65:            return TSize(11400, 22900);
      case DMPAPER_ENV_B4:             return TSize(25000, 35300);
      case DMPAPER_ENV_B5:             return TSize(17600, 25000);
      case DMPAPER_ENV_B6:             return TSize(17600, 12500);
      case DMPAPER_ENV_ITALY:          return TSize(11000, 23000);
      case DMPAPER_ENV_MONARCH:        return TSize( 9843, 19050);
      case DMPAPER_ENV_PERSONAL:       return TSize( 9208, 16510);
      case DMPAPER_FANFOLD_US:         return TSize(37783, 27940);
      case DMPAPER_FANFOLD_STD_GERMAN: return TSize(21590, 30480);
      case DMPAPER_FANFOLD_LGL_GERMAN: return TSize(21590, 33020);
    }
    return null;
  }




/// ***********************



  /*
   * Scroll Bar Constants
   */
  static const int SB_HORZ = 0;
  static const int SB_VERT = 1;
  static const int SB_CTL  = 2;
  static const int SB_BOTH = 3;

  /*
   * Scroll Bar Commands
   */
  static const int SB_LINEUP           = 0;
  static const int SB_LINELEFT         = 0;
  static const int SB_LINEDOWN         = 1;
  static const int SB_LINERIGHT        = 1;
  static const int SB_PAGEUP           = 2;
  static const int SB_PAGELEFT         = 2;
  static const int SB_PAGEDOWN         = 3;
  static const int SB_PAGERIGHT        = 3;
  static const int SB_THUMBPOSITION    = 4;
  static const int SB_THUMBTRACK       = 5;
  static const int SB_TOP              = 6;
  static const int SB_LEFT             = 6;
  static const int SB_BOTTOM           = 7;
  static const int SB_RIGHT            = 7;
  static const int SB_ENDSCROLL        = 8;


  /*
   * ShowWindow() Commands
   */
  static const int SW_HIDE             = 0;
  static const int SW_SHOWNORMAL       = 1;
  static const int SW_NORMAL           = 1;
  static const int SW_SHOWMINIMIZED    = 2;
  static const int SW_SHOWMAXIMIZED    = 3;
  static const int SW_MAXIMIZE         = 3;
  static const int SW_SHOWNOACTIVATE   = 4;
  static const int SW_SHOW             = 5;
  static const int SW_MINIMIZE         = 6;
  static const int SW_SHOWMINNOACTIVE  = 7;
  static const int SW_SHOWNA           = 8;
  static const int SW_RESTORE          = 9;
  static const int SW_SHOWDEFAULT      = 10;
  static const int SW_FORCEMINIMIZE    = 11;
  static const int SW_MAX              = 11;


  /*
   * Virtual Keys, Standard Set
   */
  static const int VK_LBUTTON =       0x01;
  static const int VK_RBUTTON =       0x02;
  static const int VK_CANCEL =        0x03;


  

  static const int VK_BACK =          0x08;
  static const int VK_BACKSPACE =     0x08; 
  static const int VK_TAB =           0x09;

  

  static const int VK_CLEAR =         0x0C;
  static const int VK_RETURN =        0x0D;

  static const int VK_SHIFT =         0x10;
  static const int VK_CONTROL =       0x11;
  static const int VK_MENU =          0x12;
  static const int VK_PAUSE =         0x13;
  static const int VK_CAPITAL =       0x14;


  static const int VK_ESCAPE =        0x1B;


  static const int VK_SPACE =         0x20;
  static const int VK_PAGEUP =        0x21; 
  static const int VK_PRIOR =         0x21;
  static const int VK_NEXT =          0x22;
  static const int VK_PAGEDOWN =      0x22; 
  static const int VK_END =           0x23;
  static const int VK_HOME =          0x24;
  static const int VK_LEFT =          0x25;
  static const int VK_UP =            0x26;
  static const int VK_RIGHT =         0x27;
  static const int VK_DOWN =          0x28;
  static const int VK_SELECT =        0x29;
  static const int VK_PRINT =         0x2A;
  static const int VK_EXECUTE =       0x2B;
  static const int VK_SNAPSHOT =       0x2C;
  static const int VK_INSERT =        0x2D;
  static const int VK_DELETE =        0x2E;
  static const int VK_HELP =          0x2F;


  static const int VK_MULTIPLY =      0x6A;
  static const int VK_ADD =           0x6B;
  static const int VK_SEPARATOR =     0x6C;
  static const int VK_SUBTRACT =      0x6D;
  static const int VK_DECIMAL =       0x6E;
  static const int VK_DIVIDE =        0x6F;

  static const int VK_F1 =            0x70;
  static const int VK_F2 =            0x71;
  static const int VK_F3 =            0x72;
  static const int VK_F4 =            0x73;
  static const int VK_F5 =            0x74;
  static const int VK_F6 =            0x75;
  static const int VK_F7 =            0x76;
  static const int VK_F8 =            0x77;
  static const int VK_F9 =            0x78;
  static const int VK_F10 =           0x79;
  static const int VK_F11 =           0x7A;
  static const int VK_F12 =           0x7B;
  static const int VK_F13 =           0x7C;
  static const int VK_F14 =           0x7D;
  static const int VK_F15 =           0x7E;
  static const int VK_F16 =           0x7F;
  static const int VK_F17 =           0x80;
  static const int VK_F18 =           0x81;
  static const int VK_F19 =           0x82;
  static const int VK_F20 =           0x83;
  static const int VK_F21 =           0x84;
  static const int VK_F22 =           0x85;
  static const int VK_F23 =           0x86;
  static const int VK_F24 =           0x87;


  /*
   * WM_ACTIVATE state values
   */
  static int WA_INACTIVE    = 0;
  static int WA_ACTIVE      = 1;
  static int WA_CLICKACTIVE = 2;


  /*
   * WM_NCHITTEST and MOUSEHOOKSTRUCT Mouse Position Codes
   */

  static const int HTTRANSPARENT      = -1; // В окне, в текущий момент закрытом другим окном  того же самого потока
  static const int HTNOWHERE          = 0;  // На экранном фоне или на разделительной линии между окнами
  static const int HTCLIENT           = 1;  // В рабочей области
  static const int HTCAPTION          = 2;  // В области заголовка
/*  static const int HTSYSMENU          = 3; // В Системном меню или на кнопке Закрыть (Close) в дочернем окне
  static const int HTGROWBOX          = 4;  // На блоке управления размером (то же самое, что и HTSIZE)
  static const int HTSIZE             = THitTest.GROWBOX; // На блоке управления размером (то же самое, что и HTGROWBOX)
  static const int HTMENU             = 5;  // В меню
  static const int HTHSCROLL          = 6;  // На горизонтальной линейке прокрутки
  static const int HTVSCROLL          = 7;  // На вертикальной линейке прокрутки
  static const int HTMINBUTTON        = 8;  // На кнопке свертывания окна (Minimize)
  static const int HTMAXBUTTON        = 9;  // На кнопке развертывания окна (Maximize)*/
  static const int HTLEFT             = 10; // На левой рамке окна
  static const int HTRIGHT            = 11; // На правой рамке окна
  static const int HTTOP              = 12; // На горизонтальной верхней рамке окна
  static const int HTTOPLEFT          = 13; // На левом верхнем угле рамки окна
  static const int HTTOPRIGHT         = 14; // На правом верхнем угле рамки окна
  static const int HTBOTTOM           = 15; // На горизонтальной нижней рамке окна
  static const int HTBOTTOMLEFT       = 16; // В левом нижнем угле рамки окна
  static const int HTBOTTOMRIGHT      = 17; // В правом нижнем угле рамки окна
/*  static const int HTBORDER           = 18; // В границах окна, которое не имеет рамки установки размеров окна
  static const int HTREDUCE           = THitTest.MINBUTTON; // На кнопке свертывания окна (Minimize)
  static const int HTZOOM             = THitTest.MAXBUTTON;
  static const int HTSIZEFIRST        = THitTest.LEFT;
  static const int HTSIZELAST         = THitTest.BOTTOMRIGHT;
  static const int HTOBJECT           = 19;
  static const int HTCLOSE            = 20; // На кнопке Закрыть (Close)
  static const int HTHELP             = 21; // На кнопке Справка (Help)*/

  /*
   * Key State Masks for Mouse Messages
   */
  static const int MK_LBUTTON          = 0x0001;
  static const int MK_RBUTTON          = 0x0002;
  static const int MK_SHIFT            = 0x0004;
  static const int MK_CONTROL          = 0x0008;
  static const int MK_MBUTTON          = 0x0010;
  static const int MK_XBUTTON1         = 0x0020;
  static const int MK_XBUTTON2         = 0x0040;



  /*
   * Predefined Clipboard Formats
   */
//  static const int CF_TEXT =            1; /* text format */
//  static const int CF_BITMAP =          2; /* bitmap format */

//  static const int CF_RTFTEXT =       100; /* rtf format */
//  static const int CF_FTEXT =         101; /* delta text format */
//  static const int CF_HTML =          102; /* html format */

  static const String CF_TEXT =       'text/plain'; /* text format */
  static const String CF_FTEXT =      'text/fstr';  /* delta text format */
  static const String CF_HTML =       'text/html';  /* html format */
  static const String CF_RTFTEXT =    'text/rtf';   /* rtf format */

  static const String CF_EDITOR =     'application/editor.delta'; /* editor format */



  static dynamic SendMessage(HWND hwnd, MESSAGE message, [dynamic wParam, dynamic lParam] )
  {
    dynamic DispatchMessage(MSG msg)
    {
      TMessage Message = TMessage(msg.message);
      Message.WParam=msg.wParam;
      Message.LParam=msg.lParam;
      hwnd._mainProc(hwnd.handle, Message);
      return Message.Result;
    }

    dynamic ProcessMessage(MSG msg)
    {

      if(_application == null)
        return DispatchMessage(msg);
      else
      {
        var OnMessage = _application!.OnMessage;

          var Handled = TPointer(false);
          if(OnMessage!=null)
              OnMessage(msg, Handled);
          if(!_application!.IsHintMsg(msg) && !Handled.Value &&
             !_application!.IsMDIMsg(msg) &&
             !_application!.IsKeyMsg(msg) &&
             !_application!.IsDlgMsg(msg))
          {
            // TranslateMessage(Message);
            return DispatchMessage(msg);
          }
    
        return null;
      } 
    }

    ///  Некоторые элементы [HScrollBar] могут являтся частью компонента, для перенаправления
    ///  событий владельцу выполняется уточнение получателя
    HWND? tmp = HWND._findWindowDef(hwnd.handle, hwnd);
    if(tmp==null)
      return null;
    hwnd = tmp;

    var msg = MSG(hwnd, message, wParam, lParam);
    return ProcessMessage(msg);
  }

  static bool RegisterClass(CLASS_ID cid)
  {
    if(cid.name.isEmpty)
      return false;
    // class registry
    if(TWndStyle._styles.add(cid.name))
    {
      var rule = TWndStyle.create(cid);
      cid.defineRule(rule);
      return true;
    }
    return false;
  }


  static bool IsChild(HWND hWndParent, HWND? hWnd) =>
      hWnd!=null && hWnd.handle.parent==hWndParent.handle;

  static bool DestroyWindow(HWND hWnd)
  {
    hWnd.release();
    return true;
  }

  static bool ShowWindow(HWND hWnd, int nCmdShow)
  {
    switch(nCmdShow)
    {
      case Windows.SW_HIDE:
        if(Windows.IsWindowVisible(hWnd))
          SendMessage(hWnd, WM_SHOWWINDOW, false, null);
        return true;

      case Windows.SW_SHOW:
      case Windows.SW_SHOWNOACTIVATE:
        if(!Windows.IsWindowVisible(hWnd))
          SendMessage(hWnd, WM_SHOWWINDOW, true, null);
        return true;

      default:
        return false;
    }
  }


  static bool SetWindowPos(HWND hWnd, _HWND? hWndInsertAfter, int? x, int? y, int? cX, int? cY, int flags)
  {
    
    if(hWndInsertAfter == HWND.TOPMOST)
      hWnd.style.zIndex = '9999';

    TWindowPos pos = TWindowPos();
    pos.hwnd = hWnd;
    pos.hwndInsertAfter = hWndInsertAfter;
    pos.x = x;
    pos.y = y;
    pos.cx = cX;
    pos.cy = cY;
    pos.flags = flags;

    if(flags & Windows.SWP_NOMOVE > 0)
    {
      pos.x = null;
      pos.y = null;
    }

    if(flags & Windows.SWP_NOSIZE > 0)
    {
      pos.cx = null;
      pos.cy = null;
    }

    if(pos.x!=null || pos.y!=null || pos.cx!=null || pos.cy!=null)
    {
      
      SendMessage(hWnd, WM_WINDOWPOSCHANGING, null, pos);

      SendMessage(hWnd, WM_WINDOWPOSCHANGED, null, pos);
    }

    if(flags.and(Windows.SWP_SHOWWINDOW|Windows.SWP_HIDEWINDOW))
    {
      bool show = flags.and(Windows.SWP_SHOWWINDOW);
      SendMessage(hWnd, WM_SHOWWINDOW, show, null);
    }
    return true;
  }


  static bool IsWindowVisible(HWND hWnd)
  {
    return hWnd.style.visibility!='hidden' && hWnd.style.display!='none';
  }

  static bool IsIconic(HWND? hWnd)
  {

    return false;
  }


  /*
   * SetWindowPos Flags
   */
  static const int SWP_NOSIZE          = 0x0001;
  static const int SWP_NOMOVE          = 0x0002;
  static const int SWP_NOZORDER        = 0x0004;
  static const int SWP_NOREDRAW        = 0x0008;
  static const int SWP_NOACTIVATE      = 0x0010;
  static const int SWP_FRAMECHANGED    = 0x0020;  /* The frame changed: send WM_NCCALCSIZE */
  static const int SWP_SHOWWINDOW      = 0x0040;
  static const int SWP_HIDEWINDOW      = 0x0080;
  static const int SWP_NOCOPYBITS      = 0x0100;
  static const int SWP_NOOWNERZORDER   = 0x0200;  /* Don't do owner Z ordering */
  static const int SWP_NOSENDCHANGING  = 0x0400;  /* Don't send WM_WINDOWPOSCHANGING */

  static const int SWP_DRAWFRAME       = SWP_FRAMECHANGED;
  static const int SWP_NOREPOSITION    = SWP_NOOWNERZORDER;

  static const int SWP_DEFERERASE      = 0x2000;
  static const int SWP_ASYNCWINDOWPOS  = 0x4000;






  static HWND? SetFocus(HWND hWnd)
  {
    Element? elem = document.activeElement;

    hWnd.clientHandle.focus();

    if(elem==null)
      return null;

    return HWND.findWindow(elem);
  }

  static HWND? GetActiveWindow()
  {
    return _activeWindow;
//    return document.activeElement;
  }

  static HWND? GetFocus()
  {
    if(document.activeElement==null)
      return null;
    return HWND.findWindow(document.activeElement!);
  }



  static HWND? GetCapture()
  {
    var elem = Windows._capture;
    return elem==null? null : HWND.findWindow(elem);
  }


  static HWND? SetCapture(HWND hwnd)
  {
    var res = GetCapture();
    Windows._capture = hwnd.handle;
    return res;
  }


  static bool ReleaseCapture()
  {
    Windows._capture = null;
    return true;
  }


  static bool IsWindowEnabled(HWND hWnd)
  {
    return hWnd.style.pointerEvents!='none';
    
  }


  static HMENU CreateMenu() => HMENU(HMENU.MAINMENU);

  static HMENU CreatePopupMenu() => HMENU(HMENU.POPUPMENU);



  static bool UpdateWindow(HWND hwnd)
  {
    if(iWnd.containsKey(hwnd))
    {
      // добавить валидацию прямоугольной часть
      iWnd.remove(hwnd);
      SendMessage(hwnd, WM_PAINT, null, null);
      return true;
    }
    return false;
  }

  static HWND? SetActiveWindow(HWND? hwnd)
  {
    HWND? elem = _activeWindow;
    if(_activeWindow != null)
      SendMessage(_activeWindow!, WM_ACTIVATE, MAKELONG(WA_INACTIVE, 0), hwnd);

    _activeWindow = hwnd;
    if(_activeWindow != null)
      SendMessage(_activeWindow!, WM_ACTIVATE, MAKELONG(WA_ACTIVE, 0), elem);
    return elem;

  }



  static bool ValidateRect(HWND hWnd, TRect rect)
  {
    return true;
  }


  static void SetWindowText(HWND hWnd, String text)
  {
    SendMessage(hWnd, WM_SETTEXT, null, text);
  }



  static bool GetWindowRect(HWND? hWnd, RECT rect)
  {
    if(hWnd==null)
      return false;
    if(hWnd.handle.offsetParent==null)
      return false;
    rect.assign(hWnd.handle.borderRect);
    return true;
  }


  /*
   * MessageBox() Flags
   */

  static const int MB_OK                   =  0x0000;
  static const int MB_OKCANCEL             =  0x0001;
  static const int MB_ABORTRETRYIGNORE     =  0x0002;
  static const int MB_YESNOCANCEL          =  0x0003;
  static const int MB_YESNO                =  0x0004;
  static const int MB_RETRYCANCEL          =  0x0005;
  static const int MB_CANCELTRYCONTINUE    =  0x0006;


  static const int ID_OK                   =  0x0001;
  static const int ID_CANCEL               =  0x0002;
  static const int ID_ABORT                =  0x0003;
  static const int ID_RETRY                =  0x0004;
  static const int ID_IGNORE               =  0x0005;
  static const int ID_YES                  =  0x0006;
  static const int ID_NO                   =  0x0007;
  static const int ID_CLOSE                =  0x0008;
  static const int ID_HELP                 =  0x0009;

  static const int ID_ACTION1              =  0x1001;
  static const int ID_ACTION2              =  0x1002;
  static const int ID_ACTION3              =  0x1003;
  static const int ID_ACTION4              =  0x1004;



  static TPoint GetCursorPos()
  {
    return _mousePos.copy();
  }


  static bool ClientToScreen(HWND? hWnd, POINT pt)
  {
    if(hWnd==null)
      return false;

    var rect = hWnd.clientHandle.borderEdge;
    pt.x += rect.left.round();
    pt.y += rect.top.round();

    return true;
  }

  static bool ScreenToClient(HWND? hWnd, POINT pt)
  {
    if(hWnd==null)
      return false;

    var rect = hWnd.clientHandle.borderEdge;
    pt.x -= rect.left.round();
    pt.y -= rect.top.round();

    return true;
  }



  static HWND? WindowFromPoint(TPoint Pos)
  {
    Element? elem = document.elementFromPoint(Pos.x, Pos.y);
    return elem==null? null : HWND.findWindow(elem);
//  return document.elementFromPoint(Pos.x, Pos.y);
  }


  static WNDPROC ChangeWindowProc(HWND hwnd, WNDPROC proc)
  {

    WNDPROC last = hwnd._mainProc;
    hwnd._mainProc = proc;
    return last;
  }



  static HWND GetDesktopWindow() => HWND.DESKTOP;

  static HWND? GetParent(HWND? hWnd)
  {
    if(hWnd == null)
      return null;

    Element? elem = hWnd.handle.parent;
    if(elem==null)
      return null;
    return HWND.findWindow(elem);
  }



  /*
   * User Button Notification Codes
   */
  static const int BN_CLICKED           = 0;




  /*
   * Dialog Codes
   */
  static const int DLGC_WANTARROWS      = 0x0001;      /* Control wants arrow keys         */
  static const int DLGC_WANTTAB         = 0x0002;      /* Control wants tab keys           */
  static const int DLGC_WANTALLKEYS     = 0x0004;      /* Control wants all keys           */
  static const int DLGC_WANTMESSAGE     = 0x0004;      /* Pass message to control          */
  static const int DLGC_HASSETSEL       = 0x0008;      /* Understands EM_SETSEL message    */
  static const int DLGC_DEFPUSHBUTTON   = 0x0010;      /* Default pushbutton               */
  static const int DLGC_UNDEFPUSHBUTTON = 0x0020;      /* Non-default pushbutton           */
  static const int DLGC_RADIOBUTTON     = 0x0040;      /* Radio button                     */
  static const int DLGC_WANTCHARS       = 0x0080;      /* Want WM_CHAR messages            */
  static const int DLGC_STATIC          = 0x0100;      /* Static item: don't include       */
  static const int DLGC_BUTTON          = 0x2000;      /* Button item: can be checked      */



}

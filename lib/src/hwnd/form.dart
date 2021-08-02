part of vcl;

class HForm extends HCustomControl
{
  static final FORM = CLASS_ID('FORM');
  CLASS_ID get classID => FORM;

  void defineClassRule(TWndStyle rule)
  {
    rule.add('',
      '${ rule.block }${ rule.font }'
      'border: 1px solid gray;'
      'box-shadow: 5px 5px 10px rgba(0,0,0,.25);'
      'background-color: ${ clBtnFace.html };'
      'box-sizing: border-box;'
      'margin: 5px;');

    rule.addRule('.form_overlay',
      'display: block;'
      'position: absolute;'
      'top: 0%;'
      'left: 0%;'
      'width: 100%;'
      'height: 100%;'
      'background-color: black;'
      '-moz-opacity: 0;'
      'opacity:.0;'
      'filter: alpha(opacity=0);');

    rule.add('.client',
      'position: absolute;'
      'overflow: auto;');

    rule.add('.title',
      'background: radial-gradient(#6060ff, #a0a0ff);'
      'text-shadow: 1px  1px 0 #6060ff,'
                   '1px -1px 0 #6060ff,'
                  '-1px  1px 0 #6060ff,'
                  '-1px -1px 0 #6060ff;'
      'color: white;'
      'box-sizing: border-box;');

    rule.add('.inactive',
      'background: radial-gradient(#808080, #c0c0c0);'
      'text-shadow: 1px  1px 0 #808080,'
                   '1px -1px 0 #808080,'
                  '-1px  1px 0 #808080,'
                  '-1px -1px 0 #808080;');

    rule.add('.caption',
      '${ rule.inline }${ rule.no_select }'
      'padding: 4px 20px 4px 4px;'
      'font-family: Arial, sans-serif;'
      'font-size: 12pt;'
      'font-weight: bolder;'
      'line-height: 1;'
      'margin: 0;');

    rule.add('.btn-close',
      'font-size: 22px;'
      'position: absolute;'
      'right: 4px;'
      'top: -1px;'
      '-webkit-user-select: none;'
      '-moz-user-select: none;'
      '-ms-user-select: none;'
      'ser-select: none;');

    rule.add('.btn-close:hover',
      'text-shadow: 0px 0px 1px white;'
      'font-weight: bolder;'
      'color: red;');
  }

  static int _zOrder = 1000;
  static int get zOrder => _zOrder;

  final title = DivElement();
  final caption = HeadingElement.h2();
  final client = DivElement();
  final close = AnchorElement();
  final overlay = DivElement();

  HWND? ownedWindow;

  Element getClientHandle() => client;

  void Close() => hide();




  HMENU? _menu;
  HMENU? get Menu => _menu;
  set Menu(HMENU? Value)
  {
    if(_menu == Value)
       return;

    if(_menu != null)
      _menu!.release();

    _menu = Value;

    if(_menu != null)
      handle.insertBefore(_menu!.handle, client);
  }

  HForm() : super()
  {
    overlay.className= 'form_overlay';
    caption.className= 'caption';
    client.className = 'client';
    title.className  = 'title';
    close.className  = 'btn-close';

    handle.append(title);
    title.append(caption);
    title.append(close);
    handle.append(client);

    int cy = SysMetric.CaptionCy;
    if(cy > 0)
      title.style.height = '${cy}px';

    handle.style.width='320px';
    handle.style.height='240px';

    close.text = '×';
    close.onClick.listen((event) => Close() );



    overlay.owner = this;
    title.owner = this;
    caption.owner = this;
    close.owner = this;
    client.owner = this;

    WNDPROC? defproc;
    defproc = Windows.ChangeWindowProc(this, (elem, message)
    { // mainproc
      switch(message.Msg)
      {
        case WM_LBUTTONDBLCLK:
          if(_wmHitTest(message.LParam)==Windows.HTCAPTION)
            Maximize=!Maximize;
          break;

        case WM_GETTEXT:
          message.Result = caption.text;
          break;

        case WM_SETTEXT:
          caption.text = message.LParam;
          break;

        case WM_NCHITTEST:
          TPoint pos = message.LParam;
          Rectangle c = handle.getBoundingClientRect();
          pos = TPoint(pos.x - c.left.round(), pos.y-c.top.round());
          message.Result = _wmHitTest(pos);
          break;

        case WM_MOUSEMOVE:

          break;

        case WM_WINDOWPOSCHANGING:
          if(Maximize)
          {
            TWMWindowPosMsg msg = TWMWindowPosMsg(message);
            msg.ElementPos.x = null;
            msg.ElementPos.y = null;
          }
          defproc!(elem, message);
          break;

        case WM_SHOWWINDOW:
          if(message.WParam)
            show();
          else
            hide();
          break;

        default:
          defproc!(elem, message);
          break;
      }
    });
  }

  void release()
  {
    overlay.remove();
    super.release();
  }

  void show()
  {
    HWND? wnd = ownedWindow;
    if(wnd == null)
      wnd = Windows.GetDesktopWindow();
    handle.style.zIndex ='${ zOrder+1 }';
    if(handle.parent == null)
      handle.parentWindow = wnd;
    handle.style.visibility=null;
  }

  void showOverlay()
  {
    if(overlay.parent == null)
    {
      overlay.style.zIndex ='${_zOrder++}';
      handle.style.zIndex ='${_zOrder++}';
      document.body!.append(overlay);
    }
  }

  TRect? _mbounds;

  bool get Maximize => _mbounds != null;
  set Maximize(bool Value)
  {
    if(Maximize == Value)
      return;
    if(_mbounds == null)
    {
      TRect mem = handle.borderRect;
      TRect r = document.body!.contentRect;
      handle.style.margin = '0';
      Windows.SetWindowPos(this, null, 0, 0, r.width, r.height, 0);
      if(mem.width==0)
      {
        int w = r.width * 2 ~/ 3;
        mem.left = (r.width - w) ~/ 2;
        mem.right = mem.left + w;
      }
      if(mem.height==0)
      {
        int h = r.height * 2 ~/ 3;
        mem.top = (r.height - h) ~/ 2;
        mem.bottom = mem.top + h;
      }
      _mbounds = mem;
    }
    else
    {
      handle.style.margin = '5px';
      TRect bnd = _mbounds!;

      _mbounds=null;
      Windows.SetWindowPos(this, null, bnd.left, bnd.top, bnd.width, bnd.height, 0);
    }
  }

  void hide()
  {
    if(overlay.parent != null)
    {
      overlay.remove();
      _zOrder-=2;
    }

    if(handle.parent == null)
      return;

  //  zOrder--;
    handle.remove();
  }



  int _wmHitTest(TPoint pos)
  {


    Rectangle m = handle.marginEdge;
    Rectangle b = handle.borderEdge;

    TRect r = TRect.size((m.left-b.left).toInt(), (m.top-b.top).toInt(), m.width.toInt(), m.height.toInt());
    if(PtInRect(r, pos) == false)
      return Windows.HTNOWHERE;

    int size = 4;
    bool top = pos.y < size;
    bool left = pos.x < size;
    bool right = pos.x > b.width-size;
    bool bottom = pos.y > b.height-size;

    if(top)
    {
      if(left)
        return Windows.HTTOPLEFT;
      if(right)
        return Windows.HTTOPRIGHT;
      return Windows.HTTOP;
    }

    if(bottom)
    {
      if(left)
        return Windows.HTBOTTOMLEFT;
      if(right)
        return Windows.HTBOTTOMRIGHT;
      return Windows.HTBOTTOM;
    }

    if(Title && pos.y < SysMetric.CaptionCy)
      return Windows.HTCAPTION;

    if(left)
      return Windows.HTLEFT;
    if(right)
      return Windows.HTRIGHT;

    return Windows.HTCLIENT;
  }

  bool get Title => title.parent != null;
  void set Title(bool Value)
  {
    if(Title==Value)
      return;
    if(Value)
      handle.append(title);
    else
      title.remove();

  }
}
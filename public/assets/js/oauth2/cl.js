var CL = {
  urls : {
    apps : 'http://apps.renren.com',
    proxy : 'http://apps.renren.com/static/proxy.html'
  },
  //CL.guid
  guid : function() {
    return 'f' + (Math.random() * (1 << 30)).toString(16).replace('.', '');
  }
};
/**
 * 这里是很多工具方法的定义，源于mootools
 *
 * @private
 */
var overloadSetter = function(fn) {
  return function(s, a, b) {
    if(a == null)
      return s;
    if( typeof a != 'string') {
      for(var k in a)
      fn.call(s, k, a[k]);
    } else {
      fn.call(s, a, b);
    }
    return s;
  };
}, typeOf = function(item) {
  if(item == null)
    return 'null';
  if( item instanceof String || typeof item == 'string')
    return 'string';
  if( item instanceof Array)
    return 'array';
  if(item.nodeName) {
    if(item.nodeType == 1)
      return 'element';
    if(item.nodeType == 3)
      return (/\S/).test(item.nodeValue) ? 'textnode' : 'whitespace';
  } else if( typeof item.length == 'number') {
    if(item.callee)
      return 'arguments';
    if('item' in item)
      return 'collection';
  }
  return typeof item;
}, guid = function() {
  return (Math.random() * (1 << 30)).toString(36).replace('.', '');
}, extend = overloadSetter(function(key, value) {
  this[key] = value;
}), implement = overloadSetter(function(key, value) {
  this.prototype[key] = value;
}), bind = function(fn, thisobj, args) {
  return function() {
    if(!args && !arguments.length)
      return fn.call(thisobj);
    if(args && arguments.length)
      return fn.apply(thisobj, args.concat(Array.from(arguments)));
    return fn.apply(thisobj, args || arguments);
  };
}, cloneOf = function(item) {
  switch (typeOf(item)) {
    case 'array' :
    case 'object' :
      return clone(item);
    default :
      return item;
  }
}, clone = function(original) {
  if(typeOf(original) == 'array') {
    var i = original.length, clone = new Array(i);
    while(i--)
    clone[i] = cloneOf(original[i]);
    return clone;
  } else if(typeOf(original) == 'string') {
    return new String(original);
  }
  var clone = {};
  for(var key in original)
  clone[key] = cloneOf(original[key]);
  return clone;
}, forEach = function(object, fn, bind) {
  if(typeOf(object) == 'array') {
    for(var i = 0, l = object.length; i < l; i++) {
      if( i in object)
        fn.call(bind, object[i], i, object);
    }
  } else
    for(var key in object) {
      if(Object.prototype.hasOwnProperty.call(object, key))
        fn.call(bind, object[key], key, object);
    }
}, indexOf = function(array, item, from) {
  var len = array.length;
  for(var i = (from < 0) ? Math.max(0, len + from) : from || 0; i < len; i++) {
    if(array[i] === item)
      return i;
  }
  return -1;
}, mergeOne = function(source, key, current) {
  switch (typeOf(current)) {
    case 'object' :
      if(typeOf(source[key]) == 'object')
        merge(source[key], current);
      else
        source[key] = clone(current);
      break;
    case 'array' :
      source[key] = clone(current);
      break;
    default :
      source[key] = current;
  }
  return source;
}, merge = function(source, k, v) {
  if(typeOf(k) == 'string')
    return mergeOne(source, k, v);
  for(var i = 1, l = arguments.length; i < l; i++) {
    var object = arguments[i];
    for(var key in object)mergeOne(source, key, object[key]);
  }
  return source;
}, combineOne = function(source, key, value) {
  var st = typeOf(source[key]);
  switch (typeOf(value)) {
    case 'object' :
    case 'array' :
      if(st == 'object')
        combine(source[key], value);
      else if(st == 'array') {
        var array = clone(value);
        for(var i = 0, l = array.length; i < l; i++) {
          if(indexOf(source[key], array[i]) == -1)
            source[key].push(array[i]);
        }
      } else if(st == 'null')
        source[key] = clone(value);
      break;
    default :
      if(st == 'null')
        source[key] = value;
  }
  return source;
}, combine = function(source, k, v) {
  if(typeOf(k) == 'string')
    return combineOne(source, k, v);
  for(var i = 1, l = arguments.length; i < l; i++) {
    var object = arguments[i];
    for(var key in object)combineOne(source, key, object[key]);
  }
  return source;
}, append = function(original) {
  for(var i = 1, l = arguments.length; i < l; i++) {
    if(typeOf(original) == 'array') {
      var atp = typeOf(arguments[i]);
      if(atp == 'array' || atp == 'arguments') {
        for(var j = 0, lg = arguments[i].length; j < lg; j++)
        original.push(arguments[i][j]);
      } else if(atp != 'null')
        original.push(arguments[i]);
    } else {
      var extended = arguments[i] || {};
      for(var key in extended)
      original[key] = extended[key];
    }
  }
  return original;
}, parsePiece = function(key, val, base) {
  var sliced = /([^\]]*)\[([^\]]*)\](.*)?/.exec(key);
  if(!sliced) {
    base[key] = val;
    return;
  }
  var prop = sliced[1], subp = sliced[2], others = sliced[3];
  if(!isNaN(subp)) {
    var numVal = +subp;
    if(subp === numVal.toString(10)) {
      subp = numVal;
    }
  }
  base[prop] = base[prop] || ( typeof subp == 'number' ? [] : {});
  if(others == null)
    base[prop][subp] = val;
  else
    parsePiece('' + subp + others, val, base[prop]);
}, fromQueryString = function(qs) {
  var decode = function(s) {
    return decodeURIComponent(s.replace(/\+/g, ' '));
  }, params = {}, parts = qs.split('&'), pair, val;
  for(var i = 0; i < parts.length; i++) {
    pair = parts[i].split('=', 2);
    if(pair && pair.length == 2) {
      val = decode(pair[1]);
      if(typeOf(val) == 'string') {
        val = val.replace(/^\s+|\s+$/g, '');
        // convert numerals to numbers
        if(!isNaN(val)) {
          numVal = +val;
          if(val === numVal.toString(10)) {
            val = numVal;
          }
        }
      }
      parsePiece(decode(pair[0]), val, params);
    }
  }
  return params;
}, toQueryString = function(object, base) {
  var queryString = [];
  forEach(object, function(value, key) {
    if(base)
      key = base + '[' + key + ']';
    var result;
    switch (typeOf(value)) {
      case 'object' :
        result = toQueryString(value, key);
        break;
      case 'array' :
        var qs = {};
        forEach(value, function(val, i) {
          qs[i] = val;
        });
        result = toQueryString(qs, key);
        break;
      case 'string' :
      case 'number' :
        result = encodeURIComponent(key) + '=' + encodeURIComponent(value);
        break;
    }
    if(result && value != null)
      queryString.push(result);
  });
  return queryString.join('&');
}, special = {
  '\b' : '\\b',
  '\t' : '\\t',
  '\n' : '\\n',
  '\f' : '\\f',
  '\r' : '\\r',
  '"' : '\\"',
  '\\' : '\\\\'
}, escape = function(chr) {
  return special[chr] || '\\u' + ('0000' + chr.charCodeAt(0).toString(16)).slice(-4);
}, validateJSON = function(string) {
  string = string.replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g, '@').replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g, ']').replace(/(?:^|:|,)(?:\s*\[)+/g, '');
  return (/^[\],:{}\s]*$/).test(string);
}, parseJSON = function(string) {
  if(!string || typeOf(string) != 'string')
    return null;
  if(window.JSON && window.JSON.parse)
    return window.JSON.parse(string);
  if(!validateJSON(string))
    throw new Error("Invalid JSON: " + string);
  return eval('(' + string + ')');
}, toJSON = window.JSON && window.JSON.stringify ? function(obj) {
  return window.JSON.stringify(obj);
} : function(obj) {
  if(obj && obj.toJSON)
    obj = obj.toJSON();
  switch (typeOf(obj)) {
    case 'string' :
      return '"' + obj.replace(/[\x00-\x1f\\"]/g, escape) + '"';
    case 'array' :
      var string = [];
      forEach(obj, function(value, key) {
        var json = toJSON(value);
        if(json)
          string.push(json);
      });
      return '[' + string + ']';
    case 'object' :
      var string = [];
      forEach(obj, function(value, key) {
        var json = toJSON(value);
        if(json)
          string.push(toJSON(key) + ':' + json);
      });
      return '{' + string + '}';
    case 'number' :
    case 'boolean' :
      return '' + obj;
    case 'null' :
      return 'null';
  }
  return null;
};
/**
 *数组操作的封装
 * */
CL.Array = {
  //c是一个数组或者
  forEach : function(c, a, f) {
    if(!c)
      return;
    if(Object.prototype.toString.apply(c) === '[object Array]' || (!( c instanceof Function) && typeof c.length == 'number')) {
      if(c.forEach) {
        c.forEach(a);
      } else
        for(var b = 0, e = c.length; b < e; b++)a(c[b], b, c);
    } else
      for(var d in c)
      if(f || c.hasOwnProperty(d))
        a(c[d], d, c);
  }
};

/**
 * json数据格式支持并 对mootools做下hack，因为开发者很喜欢用mootools嘛，So do we~
 * */
CL.JSON = {
  encode : function(object) {
    if(window.MooTools) {
      return JSON.encode(object);
    }
    return toJSON(object);
  },
  decode : function(string) {
    return parseJSON(string);
  }
};

/**
 *query string格式的支持
 * */
CL.QS = {
  encode : function(c) {
    var b = [];
    CL.Array.forEach(c, function(f, e) {
      if(f !== null && typeof f != 'undefined')
        b.push(encodeURIComponent(e) + '=' + encodeURIComponent(f));
    });
    b.sort();
    return b.join('&');
  },
  decode : function(queryString) {
    var params = {};
    var parts = queryString.split('&');
    var pair;
    for(var i = 0; i < parts.length; i++) {
      pair = parts[i].split('=', 2);
      if(pair || pair[0]) {
        params[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1] || '');
      }
    }
    return params;
  }
}

CL.XD = {

  _origin : null,
  _transport : null,
  //暂时没用
  _callbacks : {},

  /**
   * CL.XD.resolveRelation
   * @param {} relation
   * 把一个字符串解析为相对于当前句柄的句柄，支持的字符串形式如opener,parent,top,frame[n],如果分多级中间用.来分隔
   */
  resolveRelation : function(relation) {
    var part, parts = relation.split('.'), matches;
    for(var i = 0, curNode = window; i < parts.length; i++) {
      part = parts[i];
      if(part == 'opener' || part == 'parent' || part == 'top') {
        curNode = curNode[part];
      } else if( matches = /^frames\[['"]?([a-zA-Z0-9-_]+)['"]?\]$/.exec(part)) {
        curNode = curNode.frames[matches[1]];
      } else {
        throw new SyntaxError('Malformed value to resolve: ' + relation);
      }
    }
    return curNode;
  },
  /**
   * CL.XD.init
   * @param {} option
   * 如果使用到了跨域的功能，则需要调用此方法先进行初始化
   */
  init : function(option) {
    if(CL.XD._origin) {
      return;
    }
    //标识调用页面
    CL.XD._origin = (window.location.protocol + '//' + window.location.host + '/' + CL.guid());

    //如果浏览器支持PostMessage，优先采用PostMessage的方式
    if(window.addEventListener && !window.attachEvent && window.postMessage) {
      CL.XD._transport = "PostMessage";
      CL.XD.PostMessage.init();
      //否则使用比较通用的Fragment方式，Fragment方式是通过本文件中的CL.XD.Fragment.checkAndDispatch();这句调用来实现的，具体请参考方法内部的实现
    } else {
      CL.XD._transport = "Fragment";
    }
  },
  /**
   * CL.XD.send
   * @param {} message 所要发送的信息体
   * @param {} target 所要发送的目标，是一个window类的句柄
   * @param {} origin 发送方的源，接收方根据源来判断是否接受
   * 跨域信息通过此方法来发送
   */
  send : function(message, target, origin) {    
    CL.XD[CL.XD._transport] && CL.XD[CL.XD._transport].send(message, target, origin);
  },
  /**
   * CL.XD.recv
   * @param {} message 所要接收的信息
   * 跨域接收信息的回调函数
   */
  recv : function(message) {
    var messageObject = CL.JSON.decode(message);
    var method = messageObject.method;
    var params = messageObject.params;
    //var callback = CL.XD._callbacks[messageObject.method];
    //delete CL.XD._callbacks[messageObject.method];
    //callback && callback(messageObject.params);

    //现在不能添加callback，一律由Arbiter来处理
    CL.Arbiter.inform(method, params);
  }
};

//跨域传递信息的PostMessage实现
CL.XD.PostMessage = {

  _isInitialized : false,

  /**
   * CL.XD.PostMessage.init
   * 初始化方法
   */
  init : function() {
    if(!CL.XD.PostMessage._isInitialized) {
      var callback = function(event) {
        CL.XD.recv(event.data);
      };
      //注册回调函数
      window.addEventListener ? window.addEventListener('message', callback, false) : window.attachEvent('onmessage', callback);
      CL.XD.PostMessage._isInitialized = true;
    }
  },
  /**
   * CL.XD.PostMessage.send
   * @param {} message 所要发送的信息体
   * @param {} relation 发送目标相对于当前目标的关系，比如parent表示父窗口，frame[0]表示第一个iframe，parent.parent表示父窗口的父窗口
   * @param {} origin 源信息
   */
  send : function(message, relation, origin) {
    //通过relation串解析目标句柄
    var target = CL.XD.resolveRelation(relation);
    origin = origin || '*';
    //console.log('postMessage send: ' + target.postMessage(message, 'http://apps.renren.com'));
    target.postMessage(message, 'http://apps.renren.com');
  }
};

//CL.Content 页面中动态添加HTML元素的操作都在这里定义
CL.Content = {
  ROOT_ID : "cl-root",
  _root : null,
  _hiddenRoot : null,
  _callbacks : {},

  /**
   * CL.Content.init
   * 初始化方法
   */
  init : function() {
    if(!CL.Content._root) {
      CL.Content._root = document.getElementById(CL.Content.ROOT_ID);
      if(!CL.Content._root) {
        //CL.log('The "cl-root" div has not been created.');
      }
    }
  },
  /**向parent下添加元素element
   * @param element (HTMLElement/String)
   * @param parent  (HTMLElement) (optional) 默认值为_root节点
   * @return (HTMLElement) 返回新添加的节点
   */
  //CL.Content.init
  append : function(element, parent) {
    if(!parent) {
      if(!CL.Content._root) {
        CL.Content.init();
        if(!CL.Content._root) {
          return;
        }
      }
      parent = CL.Content._root;
    }
    if( typeof element == 'string') {
      var elementDiv = document.createElement('div');
      parent.appendChild(elementDiv).innerHTML = element;
      return elementDiv;
    } else {
      return parent.appendChild(element);
    }
  },
  /**向_root下的_hiddenRoot下添加元素element
   * @param element (HTMLElement/String)
   * @return (HTMLElement) 返回新添加的节点
   */
  appendHidden : function(element) {
    //初始化隐藏div
    if(!CL.Content._hiddenRoot) {
      var hiddenRoot = document.createElement('div');
      var hiddenRootStyle = hiddenRoot.style;
      hiddenRootStyle.position = 'absolute';
      hiddenRootStyle.top = '-10000px';
      hiddenRootStyle.width = 0;
      hiddenRootStyle.height = 0;
      CL.Content._hiddenRoot = CL.Content.append(hiddenRoot);
    }
    return CL.Content.append(element, CL.Content._hiddenRoot);
  },
  /**插入一个iframe
   * @param iframeObject (Object) 表征一个iframe元素的对象
   *   url: frame的src
   *   root：要把iframe插入到的节点
   *   onload：加载完成的回调
   */
  insertIframe : function(iframeObject) {
    iframeObject.id = iframeObject.id || CL.guid();
    iframeObject.name = iframeObject.name || CL.guid();

    //保存onload函数
    var callbackKey = CL.guid(), f = false, d = false;
    CL.Content._callbacks[callbackKey] = iframeObject.onload;

    if(document.attachEvent) {
      var iframeInnerHTML = ('<iframe' + ' id="' + iframeObject.id + '"' + ' name="' + iframeObject.name + '"' + (iframeObject.title ? ' title="' + e.title + '"' : '') + (iframeObject.className ? ' class="' + iframeObject.className + '"' : '') + ' style="border:none;' + (iframeObject.width ? 'width:' + iframeObject.width + 'px;' : '') + (iframeObject.height ? 'height:' + iframeObject.height + 'px;' : '') + '"' + ' src="' + iframeObject.url + '"' + ' frameborder="0"' + ' scrolling="no"' + ' allowtransparency="true"' + ' onload="CL.Content._callbacks.' + callbackKey + '()"' + '></iframe>');
      iframeObject.root.innerHTML = '<iframe src="javascript:false"' + ' frameborder="0"' + ' scrolling="no"' + ' style="height:1px"></iframe>';
      window.setTimeout(function() {
        iframeObject.root.innerHTML = iframeInnerHTML;
      }, 0);
    } else {
      var iframeElement = document.createElement('iframe');
      iframeElement.id = iframeObject.id;
      iframeElement.name = iframeObject.name;
      iframeElement.onload = CL.Content._callbacks[callbackKey];
      iframeElement.scrolling = 'no';
      iframeElement.style.border = 'none';
      iframeElement.style.overflow = 'hidden';
      if(iframeObject.title)
        iframeElement.title = iframeObject.title;
      if(iframeObject.className)
        iframeElement.className = iframeObject.className;
      if(iframeObject.height)
        iframeElement.style.height = iframeObject.height + 'px';
      if(iframeObject.width)
        iframeElement.style.width = iframeObject.width + 'px';
      iframeObject.root.appendChild(iframeElement);
      iframeElement.src = iframeObject.url;
    }
  }
};

//跨域传递信息的Fragment实现
CL.XD.Fragment = {
  _proxyUrl : CL.urls.proxy,
  _magic : "cl_xd_fragment",

  /**
   * CL.XD.Fragment.send
   * @param {} message 是个json字符串，所要发送的信息
   * @param {} target 发送目标的句柄
   * @param {} origin 发送方的源
   */
  send : function(message, target, origin) {
    //if(origin && origin.indexOf(target.location.protocol + '//' + target.location.host + '/') == 0) {
    //  target.CL.XD.recv(message);
    //}
    var request = {};
    request.fragment = CL.XD.Fragment._magic;
    request.relation = "parent." + target;
    //创建的iframe对象的parent才是当前窗口
    request.message = message;
    var iframeSrc = CL.XD.Fragment._proxyUrl + '#' + CL.QS.encode(request);
    var hiddenElement = CL.Content.appendHidden('');
    CL.Content.insertIframe({
      url : iframeSrc,
      root : hiddenElement,
      width : 1,
      height : 1,
      onload : function() {
        setTimeout(function() {
          hiddenElement.parentNode.removeChild(hiddenElement);
        }, 10);
      }
    });
  },
  /**
   * CL.XD.Fragment.send
   * 这个方法会检测自己的url，如果匹配的上一定的模式就会使用Fragment的方式把#后面的信息跨域发送出去
   */
  checkAndDispatch : function() {
    var location = window.location.toString();
    var fragment = location.substr(location.indexOf('#') + 1);
    var magicIndex = location.indexOf(CL.XD.Fragment._magic);
    if(magicIndex > 0) {
      document.documentElement.style.display = 'none';
      var request = CL.QS.decode(fragment);
      document.domain = 'renren.com';
      CL.XD.resolveRelation(request.relation).CL.XD.recv(request.message);
    }
  }
};

//自检，如果是fragment则调用XD的recv方法
CL.XD.Fragment.checkAndDispatch();

//页面中所支持的操作都在CL.Arbiter中定义
CL.Arbiter = {
  inform : function(method, params) {
    CL.Arbiter[method](params);
  },
  resize : function(params) {
    var width = params.width;
    var height = params.height;
    if(width > 2000)
      width = 2000;
    else if(width < 720)
      width = 720;

    var inner_iframe = document.getElementById("iframe_canvas");
    inner_iframe.style.width = width + 'px';
    inner_iframe.style.height = height + 'px';
    //修改导航条的宽度
    navResize();
  },
  fixtop : function(params) {
    window.scrollTo(0, 0);
  }
}

//Canvas相关的操作都在这里做出了定义
CL.Canvas = {
  /**
   * CL.Canvas.resize
   * resize方法改变iframe的高度和宽度
   */
  resize : function(params) {
    var request = {
      method : "resize",
      params : params
    };
    var message = CL.JSON.encode(request);
    CL.XD.init();
    CL.XD.send(message, "parent");
  },
  /**
   * CL.Canvas.autosize
   * 先计算内部Canvas的iframe的高度和宽度，然后调用resize方法改变iframe的高度和宽度
   */
  autosize : function() {
    var isStrict = document.compatMode != "BackCompat";
    var height = isStrict ? Math.max(document.documentElement.scrollHeight, document.documentElement.clientHeight) : Math.max(document.body.scrollHeight, document.body.clientHeight);
    //var width = isStrict ? Math.max(document.documentElement.scrollWidth, document.documentElement.clientWidth) : Math.max(document.body.scrollWidth, document.body.clientWidth);
    var width = Math.max(document.documentElement.scrollWidth,document.body.scrollWidth);
    
    if(navigator.userAgent.match(/Gecko/))
      height = document.documentElement.offsetHeight;
    var params = {
      width : width,
      height : height
    };
    CL.Canvas.resize(params);
  },
  /**
   * CL.Canvas.fixTop
   * 提供在应用内跳转页面scroll到顶部的方法。无需高宽度自适应，仅需通讯成功即可。
   * */
  fixTop : function() {
    var request = {
      method : "fixtop",
      params : {}
    };
    var message = CL.JSON.encode(request);
    CL.XD.init();
    CL.XD.send(message, "parent");
  }
}
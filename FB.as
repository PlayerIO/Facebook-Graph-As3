/**
 * Player.IO (www.player.io).
 *  
 * Ported from the Facebook Javascript SDK:
 * http://github.com/facebook/connect-js
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package Facebook{
	import flash.events.*;
	import flash.external.*;
	import flash.net.*;
	import flash.system.*;
	
	public class FB{
		private static var allowedMethods:Object = {GET:1,POST:1,'DELETE':1,PUT:1};
		private static var readOnlyCalls:Object = {fql_query:1,fql_multiquery:1,friends_get:1,notifications_get:1,stream_get:1,users_getinfo:1}
		private static var access_token:String = null;
		private static var app_id:String = null;
		private static var debug:Boolean = false;
		private static var uiFlashId:String = null;
		private static var uiCallbackId:Number = 0;
		private static var data:FBData = new FBData();
		
		public static function get Data() : FBData { return data; }
		
	
		/** 
		 * Initialize the Facebook API with a Facebook access_token
		 * 
		 * <p>As a bare minimum, you need to provide an access_token:<br/> <code>FB.init({access_token:"..."})</code></p>
		 * <p>If you specify debugging, a debug log will be written with trace():<br/> <code>FB.init({access_token:"...", debug:true})</code></p>
		 * <p>If you're going to call the old REST api, you might need to provide your Facebook Application ID, depending on which REST methods you're going to call:<br/> <code>FB.init({access_token:"...", app_id:'...'})</code></p>
		 * 
		 * @param params initialization object, example: <code>{access_token:"...", debug:true, app_id:'...'}</code> <br />
		 * <i>app_id is only required if using any of the old REST methods that require an app_id.</i> 
		 */
		public static function init(params:*) : void {
			debug = !!params.debug;
			app_id = params.app_id;
			if( (params.access_token+'').length < 3 ){
				error("You must supply the init method with an not-null access_token string.");
			}else{
				access_token = params.access_token;
				log("Initializing with access_token: " + access_token);
			}
		}

		/**
		 * Make a API call to the Facebook Graph API.
		 * 
		 * <p>Here is a sample of getting the /me resource via the Graph API<br>
		 *<listing>
		 *FB.api('/me', function(response) {
		 *	trace(FB.toString(response)); // FB.toString() simply prettyprints the object
		 *});
		 *</listing>
		 * </p>
		 * 
		 * <p>This method works exactly the same as the <a href="http://developers.facebook.com/docs/reference/javascript/FB.api">FB.api() method
		 * of the Facebook Javascript SDK</a>, so please look at that method for deeper documentation.</p>
		 * 
		 * @access public
		 * @param path {String} the url path
		 * @param method {String} the http method (default `"GET"`)
		 * @param params {Object} the parameters for the query
		 * @param cb {Function} the callback function to handle the response
		 */
		public static function api(...args) : void{
			requireAccessToken('api');
			if( typeof(args[0]) == 'string'){
				graphCall.apply(null, args);
			}else{
				restCall.apply(null, args);
			}
		}
		
		/**
		 * Indicates whether it's possible to call the FB.ui() method.
		 * 
		 * </p>The property will be true if the flash file is currently
		 * running in a webpage with allowNetworking not set to 'none'
		 * AND where the Facebook Javascript SDK is included in the page.</p>
		 */
		public static function get uiAvailable() : Boolean {
			return initUI() == null;
		}
		
		/** 
		 * Method for triggering UI interaction with Facebook as iframe dialogs or popups, like publishing to the stream, sharing links.
		 * 
		 * <p>Here is a sample of getting the /me resource via the Graph API<br>
		 *<listing>
		 *FB.ui({method:'stream.share', u:'http://player.io'}, function(response) {
		 *	trace(FB.toString(response)); // FB.toString() simply prettyprints the object
		 *});
		 *</listing>
		 * </p>
		 * 
		 * <p>This method works exactly the same as the <a href="http://developers.facebook.com/docs/reference/javascript/FB.ui">FB.ui() method
		 * of the Facebook Javascript SDK</a>, so please look at that method for deeper documentation.</p>

		 * <p>This method is implemented by proxying calls over to the Facebook Javascript SDK included in the containing webpage via ExternalInterface. In other words, this method only works
		 * if the containing page includes the Facebook Javascript SDK and the flash file is embeded with allowNetworking not set to 'none'.</p>
		 * @param params {Object} the parameters for the query
		 * @param cb {Function} the callback function to handle the response
		 */
		public static function ui(params:*, cb:Function) : void {
			// check that everything is groovy	
			var err:String = initUI();
			if(err != null){
				error(err);
			}

			// ensure method is specified
			if (!params.method) {
				error('"method" is a required parameter for FB.ui().');
			}
			
			// create a callback method especially for this call
			var callbackId:String = "as_ui_callback_"+(uiCallbackId++)
			ExternalInterface.addCallback(callbackId, function(response:*) : void{
				log("Got response from Javascript FB.ui: " + toString(response));
				cb(response);
			});
			
			// call upon the __doFBUICall method to perform the FB.ui() call for us.
			ExternalInterface.call("__doFBUICall", uiFlashId, params, callbackId);
		}
		
		private static function initUI() : String{
			if(uiFlashId==null){
				// allow javascript to talk into flash file.
				Security.allowDomain('*')
					
				// check that this flash element can use external interface
				var allowsExternalInterface:Boolean = false;
				try{ allowsExternalInterface = ExternalInterface.call("eval","true") }catch(e:*){}
				if(!allowsExternalInterface){
					return ("The flash element must not have allowNetworking = 'none' in the containing page in order to call the FB.ui() method.");
				}
				
				// check for the Facebook Javascript SDK on the containing page
				var hasJavascript:Boolean = ExternalInterface.call("eval","typeof(FB)!='undefined' && typeof(FB.ui)!='undefined'");
				if(!hasJavascript){
					return ("The FB.ui() method can only be used when the containing page includes the Facebook Javascript SDK. Read more here: http://developers.facebook.com/docs/reference/javascript/FB.init");
				}
				
				// generate a unique id for this flash instance
				uiFlashId = "flash_" + new Date().getTime() + Math.round(Math.random()*9999999);
				
				// expose a method that returns the id of the flash instance
				ExternalInterface.addCallback("getFlashId", function() : String{
					return uiFlashId;
				});
				
				// create a method in the containing page that will call the
				// FB.ui() method, and mashall the response back to us.
				var source:String = '';
				source += '__doFBUICall = function(uiFlashId,params,callbackId){'
				source += ' var find = function(tag){var list=document.getElementsByTagName(tag);for(var i=0;i!=list.length;i++){if(list[i].getFlashId&&list[i].getFlashId()=="'+uiFlashId+'"){return list[i]}}};';
				source += ' var flashObj = find("embed") || find("object");'
				source += ' if(flashObj != null){'
				source += '  FB.ui(params, function(response){'
				source += '   flashObj[callbackId](response);'
				source += '  })'
				source += ' }else{alert("could not find flash element on the page w/ uiFlashId: '+uiFlashId+'")}'
				source += '};'
				ExternalInterface.call("eval",source);
			}
			
			return null;
		}
		
		private static function graphCall(...args) : void{
			var method:String = null;
			var params:* = null;
			var cb:Function = null;
			var path:String = args.shift();
			var next:* = args.shift();
			while (next) {
				var type:String = typeof next;
				if (type === 'string' && method==null) {
					var m:String = next.toUpperCase()
					if( allowedMethods[m] ){
						method = m;
					}else{
						error('Invalid method passed to FB.api('+path+'): ' + next)
					}
				} else if (type === 'function' && cb==null) {
					cb = next;
				} else if (type === 'object' && params==null) {
					params = next;
				} else {
					error('Invalid argument passed to FB.api('+path+'): ' + next);
				}
				next = args.shift();
			}
			
			// normalize the input
			method = method || 'GET';
			params = params || {};
			
			// perform the web request
			log("Graph call: path=" + path +", method="+method+", params=" + toString(params));
			oauthRequest("https://graph.facebook.com" + path, method, params, cb);
		}
		
		private static function restCall(params:*, cb:Function) : void {
			// normalize the input
			var method:String = (params.method+'').toLowerCase().replace('.','_');
			params.format = 'json-strings'; // we want response returned in json format
			params.api_key = app_id; // some REST requests need the app_id, why the querystring argument is called api_key is beyond me.

			// perform the web request
			log("REST call: method="+method+", params=" + toString(params));
			oauthRequest("https://"+(readOnlyCalls[method] ? 'api-read' : 'api')+'.facebook.com/restserver.php','get',params,cb); 
		}
		
		private static function oauthRequest(url:String, method:String, params:*, cb:Function) : void{
			// make a request out of the arguments
			var request:URLRequest = new URLRequest(url);
			request.method = method;	
			request.data = new URLVariables();
			request.data.access_token = access_token;

			for(var x:* in params){
				request.data[x] = params[x];
			}

			// The Facebook Graph api uses HTTP status codes to indicate whether 
			// requests succeed or fail. However, we can't read the response text of
			// requests that not successful (any non 2xx status code), so we'll cheat
			// and use JSONP to get the graph servers to allways return a success 
			// response (200), and simply remove the function call from the response
			request.data.callback = "c";

			// perform the http request
			var loader:URLLoader = new URLLoader();
			loader.addEventListener(Event.COMPLETE, function(e:Event):void{
				var json:String = loader.data;
				
				trace("data: " + loader.data)
				// if the response is a JSONP response, remove the callback
				// so we can deal with the json inside. 
				if( json.length > 2 && json.substring(0,2)=='c(' ){ // JSONP
					json = loader.data.substring(loader.data.indexOf("(")+1,loader.data.lastIndexOf(')'));
				}
				
				// deserialize json
				var obj:* = JSON.deserialize(json);
				
				// log request completion
				if( url.substring(0,11) == 'https://api'){
					log("REST call result, method="+params.method+ " => " + toString(obj));
				}else{
					log("Graph call result, path="+url+ " => " + toString(obj));
				}
				
				// call callback with deserialized object
				cb(obj);
			})
			loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent) : void {
				error('Error in response from Facebook api servers, most likely cause is expired or invalid access_token. Error message: '+e.text);
			})
			loader.load(request);
		}
		
		private static function requireAccessToken(callerName:String) : void {
			if( access_token == null ){
				error('You must call FB.init({access_token:"...") before attempting to call FB.'+callerName+'()')
			}	
		}
		
		private static function error(msg:String) : void{
			if( debug ){
				trace("FB Error: " + msg);	
			}
			throw new Error(msg);
		}
		
		private static function log(msg:String) : void{
			if( debug ){
				trace("FB: " + msg);	
			}	
		}
		
		/**
		 * returns an easy-to-read json-like string representation of the given object
		 * 
		 * @param obj the object to get the string representation of
		 */
		public static function toString(obj:*) : String{
			if(obj == null)return "[null]";
			switch(typeof obj){
				case 'object':
					var objOut:String = '{'
					var arrayOut:String = '['
					var allNumeric:Boolean = true;
					var anyAtAll:Boolean = false;
					for(var prop:* in obj){
						objOut += (objOut=='{'?'':', ')+prop + "=" + toString(obj[prop]);
						arrayOut += (arrayOut=='['?'':', ') + toString(obj[prop]);
						if( typeof prop != 'number' ){
							allNumeric = false;	
						}
						anyAtAll = true;
					}
					return allNumeric && anyAtAll ? (arrayOut+']') : (objOut+'}');
				case 'string':
					return '"'+obj.replace("\n","\\n").replace("\r","\\r")+'"';
				default:
					return obj+'';
					break;
			}
		}
		
		
		// -------------------------------------------
		private static var _formatRE:RegExp = /(\{[^\}^\{]+\})/g;
		private static var _trimRE:RegExp = /^\s*|\s*$/g;
		private static var _quoteRE:RegExp = /["\\\x00-\x1f\x7f-\x9f]/g;
		
		/**
		 * Strip leading and trailing whitespace.
		 *
		 * @param s {String} the string to trim
		 * @returns {String} the trimmed string
		 */
		internal static function stringTrim(s:String) : String {
			return s.replace(_trimRE, '');
		}
		
		/**
		 * Format a string.
		 *
		 * Example:
		 *     FB.String.format('{0}.facebook.com/{1}', 'www', 'login.php')
		 * Returns:
		 *     'www.facebook.com/login.php'
		 *
		 * Example:
		 *     FB.String.format('foo {0}, {1}, {0}', 'x', 'y')
		 * Returns:
		 *     'foo x, y, x'
		 *
		 * @static
		 * @param format {String} the format specifier
		 * @param arguments {...} placeholder arguments
		 * @returns {String} the formatted string
		 */
		internal static function stringFormat(format:String, ...args) : String {
			// var values = arguments;
			return format.replace(_formatRE, function(str:String, m:String,index:int,completeString:String) : String{
				var	index:int = parseInt(m.substr(1), 10);
				var value:* = args[index];
				if (value === null || typeof(value) == 'undefined') {
					return '';
				}
				return value.toString();
			});
		}
		
		/**
		 * Escape an string so that it can be embedded inside another string
		 * as quoted string.
		 *
		 * @param value {String} string to quote
		 * @return {String} an quoted string
		 */
		internal static function stringQuote(value:String) : String {
			var	subst:Object = {    // table of character substitutions
				'\b': '\\b',
				'\t': '\\t',
				'\n': '\\n',
				'\f': '\\f',
				'\r': '\\r',
				'"' : '\\"',
				'\\': '\\\\'
			};
			
			return _quoteRE.test(value) ?
				'"' + value.replace(_quoteRE, function (a:String) : String {
					var c:String = subst[a];
					if (c) {
						return c;
					}
					c = a.charCodeAt();
					return '\\u00' + Math.floor(c/16).toString(16) + (c % 16).toString(16);
				}) + '"' 
				: '"' + value + '"';
		}
		
		/**
		 * Get index of item inside an array. Return's -1 if element is not found.
		 *
		 * @param arr {Array} Array to look through.
		 * @param item {Object} Item to locate.
		 * @return {Number} Index of item.
		 */
		internal static function arrayIndexOf(arr:Array, item:*) : int {
			var length:uint = arr.length;
			if (length) {
				for (var index:int = 0; index < length; index++) {
					if (arr[index] === item) {
						return index;
					}
				}
			}
			return -1;
		}
		
		/**
		 * Merge items from source into target, but only if they dont exist. Returns
		 * the target array back.
		 *
		 * @param target {Array} Target array.
		 * @param source {Array} Source array.
		 * @return {Array} Merged array.
		 */
		internal static function arrayMerge(target:Array, source:Array) : Array {
			for (var i:int=0; i < source.length; i++) {
				if (arrayIndexOf(target, source[i]) < 0) {
					target.push(source[i]);
				}
			}
			return target;
		}
		
		/**
		 * Create an array by performing transformation on the items in a source
		 * array.
		 *
		 * @param arr {Array} Source array.
		 * @param transform {Function} Transformation function.
		 * @return {Array} The transformed array.
		 */
		internal static function arrayMap(arr:Array, transform:Function) : Array{
			var ret:Array = [];
			for (var i:int=0; i < arr.length; i++) {
				ret.push(transform(arr[i]));
			}
			return ret;
		}
		
		
		/**
		 * Create an new array from the given array and a filter function.
		 *
		 * @param arr {Array} Source array.
		 * @param fn {Function} Filter callback function.
		 * @return {Array} Filtered array.
		 */
		internal static function arrayFilter(arr:Array, fn:Function) : Array {
			var b:Array = [];
			for (var i:int=0; i < arr.length; i++) {
				if (fn(arr[i])) {
					b.push(arr[i]);
				}
			}
			return b;
		}
		
		/**
		 * Copies things from source into target.
		 *
		 * @access private
		 * @param target    {Object}  the target object where things will be copied
		 *                            into
		 * @param source    {Object}  the source object where things will be copied
		 *                            from
		 * @param overwrite {Boolean} indicate if existing items should be
		 *                            overwritten
		 * @param tranform  {function} [Optional], transformation function for
		 *        each item
		 */
		internal static function objCopy(target:Object, source:Object, overwrite:Boolean, transform:Function) : Object {
			for (var key:String in source) {
				if (overwrite || typeof( target[key] ) == 'undefined') {
					target[key] = typeof(transform) == 'function' ? transform(source[key]) :  source[key];
				}
			}
			return target;
		}
		
		internal static function forEach(item:*, fn:Function) : void {
			if(!item)return;
			
			if( item is Array){
				for(var i:uint=0;i!=item.length;i++){
					fn(item[i], i, item);
				}
				
			}else if(item is Object){
				for(var x:* in item){
					fn(item[x], x, item);
				}
			}
		}
	}
}
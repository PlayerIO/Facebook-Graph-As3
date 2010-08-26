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
	import flash.system.*;
	import flash.utils.*;

	public class FBWaitable{
		private var subscribers:Object = {};
		private var _value:Object = null;
		
		public function set value(value:Object) : void{
			if( JSON.serialize(value) != JSON.serialize(_value) ){
				_value = value;
				fire("value",value);
			}
		}
		public function get value() : Object{
			return _value;
		}
		
		/**
		 * Fire the error event.
		 *
		 * @access private
		 * @param ex {Exception} the exception object
		 */
		public function error(ex:Error) : void {
			fire("error", ex);
		}
		
		/**
		 * Register a callback for an asynchronous value, which will be invoked when
		 * the value is ready.
		 *
		 * Example
		 * -------
		 *
		 * In this
		 *      val v = get_a_waitable();
		 *      v.wait(function (value) {
		 *        // handle the value now
		 *      },
		 *      function(error) {
		 *        // handle the errro
		 *      });
		 *      // later, whoever generated the waitable will call .set() and
		 *      // invoke the callback
		 *
		 * @param {Function} callback A callback function that will be invoked
		 * when this.value is set. The value property will be passed to the
		 * callback function as a parameter
		 * @param {Function} errorHandler [optional] A callback function that
		 * will be invoked if there is an error in getting the value. The errorHandler
		 * takes an optional Error object.
		 */
		public function wait(callback:Function, ...args) : void {
			var errorHandler:Function = args.length==1 && args[0] is Function ? args[0] : null;
			
			// register error handler first incase the monitor call causes an exception
			if (errorHandler != null) {
				this.subscribe('error', errorHandler);
			}
			
			var t:* = this;
			this.monitor('value', function() : Boolean {
				if (t.value != null) {
					callback(t.value);
					return true;
				}else{
					return false;				
				}
			});
		}
		
		/**
		 * Subscribe to a given event name, invoking your callback function whenever
		 * the event is fired.
		 */
		public function subscribe(name:String, cb:Function) : void {
			if (!subscribers[name]) {
				subscribers[name] = [cb];
			} else {
				subscribers[name].push(cb);
			}
		}
		
		/**
		 * Removes subscribers, inverse of [FB.Event.subscribe](FB.Event.subscribe).
		 */
		public function unsubscribe(name:String, cb:Function) : void {
			var subs:Array = subscribers[name];
			
			if( subs ){
				for( var i:int = 0;i!=subs.length;i++){
					if( subs[i] == cb ){
						subs[i] = null;
					}
				}
			}
		}
		
		/**
		 * Repeatedly listen for an event over time. The callback is invoked
		 * immediately when monitor is called, and then every time the event
		 * fires. The subscription is canceled when the callback returns true.
		 *
		 * @access private
		 * @param {string} name Name of event.
		 * @param {function} callback A callback function. Any additional arguments
		 * to monitor() will be passed on to the callback. When the callback returns
		 * true, the monitoring will cease.
		 */
		public function monitor(name:String, callback:Function) : void {
			if (!callback()) {
				var	ctx:FBWaitable = this;
				var fn:Function = function(...args) : void {
					if (callback.apply(callback, args)) {
						ctx.unsubscribe(name, fn);
					}
				};
				
				subscribe(name, fn);
			}
		}
		
		/**
		 * Removes all subscribers for named event.
		 */
		public function clear(name:String) : void {
			delete subscribers[name];
		}
		
		/**
		 * Fires a named event. The first argument is the name, the rest of the
		 * arguments are passed to the subscribers.
		 *
		 * @access private
		 * @param name {String} the event name
		 */
		public function fire(name:String, ...args) : void {
			var subs:Array = subscribers[name];

			if( subs ){
				for( var i:int = 0;i!=subs.length;i++){
					if( subs[i] != null ){
						subs[i].apply(this,args);
					}
				}
			}
		}
	}
}
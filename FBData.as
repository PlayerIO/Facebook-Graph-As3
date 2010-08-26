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
	import flash.utils.*;

	public class FBData{
		private var timer:int = -1;
		private var queue:Array = [];
		
		public function query(template:String, ...args) : FBQuery{
			var query:FBQuery = new FBQuery().parse(template, args);
			queue.push(query);
			_waitToProcess();
			return query;
		}
		
		/**
		 * Wait until the results of all queries are ready. See also
		 * [FB.Data.query](FB.Data.query) for more examples of usage.
		 *
		 * Examples
		 * --------
		 *
		 * Wait for several queries to be ready, then perform some action:
		 *
		 *      var queryTemplate = 'select name from profile where id={0}';
		 *      var u1 = FB.Data.query(queryTemplate, 4);
		 *      var u2 = FB.Data.query(queryTemplate, 1160);
		 *      FB.Data.waitOn([u1, u2], function(args) {
		 *        log('u1 value = '+ args[0].value);
		 *        log('u2 value = '+ args[1].value);
		 *      });
		 *
		 * Same as above, except we take advantage of JavaScript closures to
		 * avoid using args[0], args[1], etc:
		 *
		 *      var queryTemplate = 'select name from profile where id={0}';
		 *      var u1 = FB.Data.query(queryTemplate, 4);
		 *      var u2 = FB.Data.query(queryTemplate, 1160);
		 *      FB.Data.waitOn([u1, u2], function(args) {
		 *        log('u1 value = '+ u1.value);
		 *        log('u2 value = '+ u2.value);
		 *      });
		 *
		 * Create a new Waitable that computes its value based on other Waitables:
		 *
		 *      var friends = FB.Data.query('select uid2 from friend where uid1={0}',
		 *                                  FB.getSession().uid);
		 *      // ...
		 *      // Create a Waitable that is the count of friends
		 *      var count = FB.Data.waitOn([friends], 'args[0].length');
		 *      displayFriendsCount(count);
		 *      // ...
		 *      function displayFriendsCount(count) {
		 *        count.wait(function(result) {
		 *          log('friends count = ' + result);
		 *        });
		 *      }
		 *
		 * You can mix Waitables and data in the list of dependencies
		 * as well.
		 *
		 *      var queryTemplate = 'select name from profile where id={0}';
		 *      var u1 = FB.Data.query(queryTemplate, 4);
		 *      var u2 = FB.Data.query(queryTemplate, 1160);
		 *
		 *      // FB.getSession().uid is just an Integer
		 *      FB.Data.waitOn([u1, u2, FB.getSession().uid], function(args) {
		 *          log('u1 = '+ args[0]);
		 *          log('u2 = '+ args[1]);
		 *          log('uid = '+ args[2]);
		 *       });
		 *
		 * @param dependencies {Array} an array of dependencies to wait on. Each item
		 * could be a Waitable object or actual value.
		 * @param callback {Function} A function callback that will be invoked
		 * when all the data are ready. An array of ready data will be
		 * passed to the callback. If a string is passed, it will
		 * be evaluted as a JavaScript string.
		 * @return {FB.Waitable} A Waitable object that will be set with the return
		 * value of callback function.
		 */
		public function waitOn(dependencies:Array, callback:Function) : FBWaitable {
			var	result:FBWaitable = new FBWaitable();
			var	count:int = dependencies.length;
				
			FB.forEach(dependencies, function(item:*, index:*, original:*) : void{
				item.monitor('value', function() : Boolean {
					var done:Boolean = false;
					if (FB.Data._getValue(item) != null) {
						count--;
						done = true;
					}
					if (count == 0) {
						var value:* = callback(FB.arrayMap(dependencies, FB.Data._getValue));
						result.value = (value != null ? value : true);
					}
					return done;
				});
			})
			
			return result;
		}
		
		/**
		 * Helper method to get value from Waitable or return self.
		 *
		 * @param item {FB.Waitable|Object} potential Waitable object
		 * @returns {Object} the value
		 */
		private function _getValue(item:*) : *{
			return item is FBWaitable ? item.value : item;
		}
		
		/**
		 * Set up a short timer to ensure that we process all requests at once. If
		 * the timer is already set then ignore.
		 */
		private function _waitToProcess() : void {
			if (timer < 0) {
				timer = setTimeout(_process, 10);
			}
		}
		
		/**
		 * Process the current queue.
		 */
		private function _process() : void{
			timer = -1;
			
			var	mqueries:Object = {};
			var q:Array = queue;
			queue = [];
			
			for (var i:int=0; i < q.length; i++) {
				var item:FBQuery = q[i];
				if (item.where.type == 'index' && !item.hasDependency) {
					_mergeIndexQuery(item, mqueries);
				} else {
					mqueries[item.name] = item;
				}
			}
			
			// Now make a single multi-query API call
			var params:Object = { method: 'fql.multiquery', queries: {} };
			FB.objCopy(params.queries, mqueries, true, function(query:FBQuery) : String {
				return query.toFql();
			});
			
			params.queries = JSON.serialize(params.queries);
			
			FB.api(params, function(result:*) : void {
				if (result.error_msg) {
					for(var key:String in mqueries){
						mqueries[key].error(new Error(result.error_msg));
					}
				} else {
					for (var x:int=0; x<result.length; x++) {
						var o:* = result[x];
						mqueries[o.name].value = o.fql_result_set;
					}
				}
			});
		}
		
		/**
		 * Check if y can be merged into x
		 * @private
		 */
		private function _mergeIndexQuery(item:FBQuery, mqueries:Object) : void {
			var key:String = item.where.key;
			var	value:* = item.where.value;
			
			var name:String = 'index_' +  item.table + '_' + key;
			var master:FBQuery = mqueries[name];
			if (!master) {
				master = mqueries[name] = new FBQuery();
				master.fields = [key];
				master.table = item.table;
				master.where = {type: 'in', key: key, value: []};
			}
			
			// Merge fields
			FB.arrayMerge(master.fields, item.fields);
			FB.arrayMerge(master.where.value, [value]);
			
			// Link data from master to item
			master.wait(function(r:Array) : void {
				item.value = FB.arrayFilter(r, function(x:Object) : Boolean {
					return x[key] == value;
				});
			},
		
			// the following call is not present in the original javascript
			//   (http://github.com/facebook/connect-js/blob/master/src/data/data.js)
			// but I think it's required to make the master call out when an error occurs... 
			function(e:*) : void { item.fire("error",e); });
		}
	}
}
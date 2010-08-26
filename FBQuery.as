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
	
	public class FBQuery extends FBWaitable{
		private static var counter:int = 0;
		public var name:String = "";
		public var hasDependency:Boolean = false;
		public var fields:Array = [];
		public var table:String = null;
		public var where:Object = null;
		
		public function FBQuery(){
			name = 'v_'+(counter++);
		}

		/**
		 * Use the array of arguments using the FB.String.format syntax to build a
		 * query, parse it and populate this Query instance.
		 *
		 * @params args
		 */
		internal function parse(template:String, args:Array) : FBQuery {
			var fql:String = FB.stringFormat(template, args);
			var re:Object = (/^select (.*?) from (\w+)\s+where (.*)$/i).exec(fql); // Parse it
			this.fields = _toFields(re[1]);
			this.table = re[2];
			this.where = _parseWhere(re[3]);
			
			for (var i:uint = 0; i < args.length; i++) {
				if (args[i] is FBQuery)  {
					// Indicate this query can not be merged because
					// others depend on it.
					args[i].hasDependency = true;
				}
			}
			
			return this;
		}
		
		/**
		 * Renders the query in FQL format.
		 *
		 * @return {String} FQL statement for this query
		 */
		public function toFql() : String {
			var s:String = 'select ' + this.fields.join(',') + ' from ' + this.table + ' where ';
			switch (this.where.type) {
				case 'unknown':
					s += this.where.value;
					break;
				case 'index':
					s += this.where.key + '=' + this._encode(this.where.value);
					break;
				case 'in':
					if (this.where.value.length == 1) {
						s += this.where.key + '=' +  this._encode(this.where.value[0]);
					} else {
						s += this.where.key + ' in (' +
							FB.arrayMap(this.where.value, this._encode).join(',') + ')';
					}
					break;
			}
			return s;
		}
		
		/**
		 * Encode a given value for use in a query string.
		 *
		 * @param value {Object} the value to encode
		 * @returns {String} the encoded value
		 */
		private function _encode(value:Object) : String {
			return typeof(value) == 'string' ? FB.stringQuote(value+'') : (value+'');
		}
		
		/**
		 * Return the name for this query.
		 *
		 * TODO should this be renamed?
		 *
		 * @returns {String} the name
		 */
		public function toString() : String{
			return '#' + this.name;
		}
		
		/**
		 * Return an Array of field names extracted from a given string. The string
		 * here is a comma separated list of fields from a FQL query.
		 *
		 * Example:
		 *     query._toFields('abc, def,  ghi ,klm')
		 * Returns:
		 *     ['abc', 'def', 'ghi', 'klm']
		 *
		 * @param s {String} the field selection string
		 * @returns {Array} the fields
		 */
		private function _toFields(s:String) : Array {
			return FB.arrayMap(s.split(','), FB.stringTrim);
		}
		
		/**
		 * Parse the where clause from a FQL query.
		 *
		 * @param s {String} the where clause
		 * @returns {Object} parsed where clause
		 */
		private function _parseWhere(s:String) : Object {
			// First check if the where is of pattern key = XYZ
			var re:Object = (/^\s*(\w+)\s*=\s*(.*)\s*$/i).exec(s);
			var result:Object = null;
			var value:* = null;
			var type:String = 'unknown';

			if (re) {
				// Now check if XYZ is either an number or string.
				value = re[2];
				// The RegEx expression for checking quoted string
				// is from http://blog.stevenlevithan.com/archives/match-quoted-string
				if (/^(["'])(?:\\?.)*?\1$/.test(value)) {
					// Use eval to unquote the string
					// convert
					value = JSON.deserialize(value);
					type = 'index';
				} else if (/^\d+\.?\d*$/.test(value)) {
					type = 'index';
				}
			}
			
			if (type == 'index') {
				// a simple <key>=<value> clause
				result = { type: 'index', key: re[1], value: value };
			} else {
				// Not a simple <key>=<value> clause
				result = { type: 'unknown', value: s };
			}
			return result;
		}
	}
}
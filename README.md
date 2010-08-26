Facebook Graph As3
==================
A thin Facebook Graph client in ActionScript 3 which closely 
mirrors the methods in the official Javascript Facebook SDK.

This library is maintained by Player.IO (www.player.io),
which is a online suite of tools and services for game 
developers, such as BigDB (a database), hosted multiplayer
servers, file hosting and much more... 

Usage
-----
To use the library, just must initialize it with a valid
Facebook access_token. If you're on a canvas page in 
Facebook you can simply pass it to the Flash file via
a FlashVar.

	FB.init({ access_token:'...', debug:true })
	
If you're going to use FQL or call methods on the old REST 
api, you shuld also specify your Facebook Application ID:

	FB.init({ access_token:'...', app_id:'...', debug:true })
	
The library is ported from the official Facebook Javascript
SDK so the methods, arguments and callbacks should work
the same.

The following methods are supported in this library:

- **FB.api(...)** 
  API requests via Facebook Graph or the old REST interface.
 
- **FB.ui(...)**
  Showing various Facebook interface elements on the containing
  webpage. Notice that this method requires that the official
  Facebook Javascript SDK is included on the containing page. 	
  
- **FB.Data.* (FQL Support)**
  FQL queries including support for execution of multiple
  dependent queries in one request.
  
In addition, a simple FB.toString() method is added that
pretty-prints a given object or array in a JSON-alike
fashion.
	
### FB.api()
Make a API call to the Facebook Graph API.

The FB.api() method works exactly the same as the one in the
official Facebook Javascript SDK, so their documentation should
be directly applicable to this library:

http://developers.facebook.com/docs/reference/javascript/FB.api

Here is some sample usage of the method:

# Loading yourself:

	FB.api('/me', function(response:*) : void {
		trace(FB.toString(response));
	})
	
# Or your friends:

	FB.api({method: 'friends.get'}, function(response:*) : void {
		trace(FB.toString(response));
	})

# Posting:

	FB.api('/me/feed', 'post', { body: "message goes here" }, function(response:*) : void {
		trace(FB.toString(response));
	})
	
# An old REST method call:

	FB.api({method: 'links.getStats',urls: 'facebook.com,developers.facebook.com'},	function(response:*) : void {
		trace('Total: ' + (response[0].total_count + response[1].total_count));
	})
	
### FB.ui()
Method for triggering UI interaction with Facebook as iframe dialogs 
or popups, like publishing to the stream, sharing links.

The FB.ui() method works exactly the same as the one in the
official Facebook Javascript SDK, so their documentation should
be directly applicable to this library:

http://developers.facebook.com/docs/reference/javascript/FB.ui

This method requires that the containing page has the Facebook 
Javascript SDK included, as it works by proxying arugments directly
to the javascript version of the method.

Go here for information on how to include the Javascript SDK 
in the containing page:
http://developers.facebook.com/docs/reference/javascript/FB.init

# sample usage:
  
	FB.ui({method: 'stream.share',u: 'http://www.playerio.com/'}, function(response) : void { 
		trace(FB.toString(response)); 
	})
	
### *FB.Data.* (FQL Support)*
Support for the executing Facebook Queries and reading their
results.

The FB.Data.*() methods works exactly the same as the ones in the
official Facebook Javascript SDK, so their documentation should
be directly applicable to this library:

http://developers.facebook.com/docs/reference/javascript/FB.Data.query

# Getting name and uid of a user

	var query:FBQuery = FB.Data.query('select name, uid from user where uid={0}',user_id);
	query.wait(function(rows:Array) : void {
		trace(FB.toString(rows)); 
	},null);
	
# Error handling

	var query:FBQuery = FB.Data.query('select non_existing_column from user where uid={0}',1);
	query.wait(function(rows:Array) : void {
		trace("success... not going to happen")		
	},function(error:String) : void{
		trace("error: "+error);
	});
	
# Dependent queries

	var query:FBQuery = FB.Data.query('select username from page where page_id = 6815841748');
	var dependentQuery:FBQuery = FB.Data.query('select mr_president from page where username in (select username from {0})', query);
	
	// now wait for the results from the dependent query
	dependentQuery.wait(function(rows:Array) : void {
		trace(FB.toString(rows));
	}, function(e:String) : void{
		trace("error: " + e);
	});
	
# Heavily dependent queries

	// First, get ten of the logged-in user's friends and the events they
	// are attending. In this query, the argument is just an int value
	// (the logged-in user id). Note, we are not firing the query yet.
	var query:FBQuery = FB.Data.query("select uid, eid from event_member "
		+ "where uid in "
		+ "(select uid2 from friend where uid1 = {0}"
		+ " order by rand() limit 10)",
		user_id);
	
	// Now, construct two dependent queries - one each to get the
	// names of the friends and the events referenced
	var friends:FBQuery = FB.Data.query("select uid, name from user where uid in (select uid from {0})", query);
	var events:FBQuery = FB.Data.query("select eid, name from event where eid in (select eid from {0})", query);
	
	// Now, register a callback which will execute once all three
	// queries return with data
	FB.Data.waitOn([query, friends, events], function() : void {
		// build a map of eid, uid to name
		var eventNames:Object = {};
		var friendNames:Object = {};
		var i:uint=0;
		var row:Object
		
		for(i=0;i!=events.value.length;i++){
			row = events.value[i];
			eventNames[row.eid] = row.name;
		}
		
		for(i=0;i!=friends.value.length;i++){
			row = friends.value[i];
			friendNames[row.uid] = row.name;
		}
		   
		for(i=0;i!=query.value.length;i++){
			row = query.value[i];
			trace( friendNames[row.uid] + " is attending " + eventNames[row.eid] );
		}
	});
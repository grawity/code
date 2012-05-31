// ==UserScript==
// @name        Krautchan.net - clean up hidden threads
// @namespace   http://nullroute.eu.org/~grawity/
// @include     http://krautchan.net/*
// @version     1
// ==/UserScript==

var MAX_THREADS = 100;

// https://gist.github.com/1143845
var gm_uwin = (function(){
	var a;
	try {
		a = unsafeWindow == window ? false : unsafeWindow;
	} catch(e) { }
	return a || (function(){
		var el = document.createElement('p');
		el.setAttribute('onclick', 'return window;');
		return el.onclick();
	}());
}());

function main() {
	var param = "board."+gm_uwin.board+".hiddenthreads";
	var threads = gm_uwin.configGet(param);
	if (threads != null)
		if (threads.length > MAX_THREADS)
			gm_uwin.configSet(param, threads.slice(-MAX_THREADS));
}

window.addEventListener("load", main, true);

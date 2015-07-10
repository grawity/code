// ==UserScript==
// @name        Krautchan.net - forget old hidden threads
// @description Clean up old hidden threads to avoid hitting the 4k cookie length limit.
// @namespace   http://nullroute.eu.org/~grawity/
// @include     http://krautchan.net/*
// @version     2
// ==/UserScript==

// Let's assume 
var MAX_THREADS = 150;

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
	// cookie limit: 1 board => ~190 threads
	//           more boards => dunno
	var max = 150;
	var count = 0;
	//var re = /^board\.(.+)\.hiddenthreads$/;
	//for (var param in gm_uwin.desuConfig) {
	var param = "board."+gm_uwin.board+".hiddenthreads";
	var threads = gm_uwin.configGet(param);
	if (threads == null)
		return;
	if (threads.length > max)
		gm_uwin.configSet(param, threads.slice(-max));
}

window.addEventListener("load", main, true);

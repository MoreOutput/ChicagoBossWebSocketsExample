window.onload = function() {
	'use strict';
	var wsc = new WebSocket('ws://127.0.0.1:8001/websocket/channel'),
	msgObj = {
		id: "id of db item"
		type: "edit"
	};

	wsc.onopen = function(r) {
		wsc.send(JSON.stringify(msgObj));
	}

	wsc.onmessage = function(r) {
		console.log(r);
	}

	wsc.onerror = function(r) {
		console.log(r);
	}

	wsc.onclose = function(r) {
		console.log(r);
	}
};
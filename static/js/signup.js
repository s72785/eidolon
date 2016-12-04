// @license magnet:?xt=urn:btih:0b31508aeb0634b347b8270c7bee4d411b5d4109&dn=agpl-3.0.txt AGPL v3.0
var username = $('#username');
var hint = $('#usernamehint');
function fixUsername() {
    var s = username.val().
	toLowerCase().
	replace(/[^0-9a-z\-_]/g, "");

    if (s !== username.val())
	username.val(s);

    if (s.length > 0)
	hint.text("http://bitlove.org/" + s);
    else
	hint.text("");
}
username.bind('change', fixUsername);
username.bind('input', fixUsername);
username.bind('keyup', fixUsername);
// @license-end

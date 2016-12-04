// @license magnet:?xt=urn:btih:0b31508aeb0634b347b8270c7bee4d411b5d4109&dn=agpl-3.0.txt AGPL v3.0
$('#activate').click(function(ev) {
    var activate = $('#activate');
    activate.hide();
    ev.preventDefault();

    var token = activate.attr('data-token');
    var salt = activate.attr('data-salt');
    var password1 = $('#password1').val();
    var password2 = $('#password2').val();

    function progress(s) {
	$('#progress').text(s);
    }
    function fail(s) {
	progress(s);
	activate.show();
	return;
    }

    /* Validate form data */
    if (password1 != password2)
	return fail("Passwords must match");

    /* Calculate salted password */
    progress("Salting password");
    var salted = hmac(salt, password1);

    /* Request salt+challenge for hashing */
    progress("Requesting account activation...");
    $.ajax({ type: 'POST',
	     data: {
		 salted: salted
	     },
	     url: '/activate/' + token,
	     success: function(response) {
		 if (response && response.welcome) {
		     progress("Welcome to Eidolon!");
		     document.location = response.welcome;
		 } else {
		     fail((response && response.error) || "Cannot activate");
		 }
	     },
	     error: function() {
		 fail("Error sending request");
	     }
    });
});

function hmac(key, text) {
    var hmac = new jsSHA(text, 'ASCII');
    return hmac.getHMAC(key, 'HEX', 'SHA-1', 'HEX');
}
// @license-end

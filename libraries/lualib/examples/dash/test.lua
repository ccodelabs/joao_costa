local dashtx = require("dashtx.dashtx");
local uv = require("luv");
local dashwallet = require("dashtx.dashwallet");

--Setting the dash address, or just leave that set to my wallet :) :
--dashtx.address = "<address>";

--Setting up the debug mode
dashtx.DEBUG = true;

--Setting up the dash network fee, defaults to 200 which is sufficient for now
--dashtx.NETWORK_FEE = 200;

--Listen to transaction
local object = dashtx.startListeningToTransaction(--[[LUV handle]] uv,--[[TX label]] "Testing transaction",--[[EUR amount]] 0.008,--[[Timeout in seconds]] 60,
	function(qrCode)
		--QR code has been generated, so you can show it to customer (WARNING: can be null if this fails!)
		print("QR code generated: ", qrCode);
	end, function(success, accept, refund)
		--Transaction was either successful or not (always called!) (false on failure) (true on success)
		--If success==true the acccept and refund functions are passed as well
		print("TX success: ",success);
		if success then
			print("TX refund");
			--Vend success so accept the DASH (send to main wallet)
			--accept();
			--If vend fails call refund function (send back to customer)
			local txIdUrl = refund();
			print("Check your refund transaction here:", txIdUrl);
		end
	end, function(secondsLeft)
		--Called every second to report number of seconds left to pay
		print("Seconds left: ", secondsLeft);
	end
);


--Don't forget about uv event loop :)
while true do
	uv.run();
end
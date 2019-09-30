local cashless = require("cashless");
local uv = require("luv");

--Setting the dash address, or just leave that set to my wallet :) :
--cashless.setDashAddress("<address>"):

--Setting up the debug mode
--cashless.setDebug(true);

--Setting up the dash network fee, defaults to 200 which is sufficient for now
--cashless.setDashNetworkFee(300)

--Listen to transaction
local object = cashless.startListeningToTransaction(--[[LUV handle]] uv,--[[TX label]] "Testing transaction",--[[Timeout in seconds]] 60,
	--[[QR code show function]]
	function(qrCode, cancel)

		--QR code has been generated, so you can show it to customer (WARNING: can be null if this fails!)
		print("QR code generated: ", qrCode);

		--You can also cancel the transaction with cancel function (if the user presses cancel button or whatever)
		--cancel();

	end,
	--[[Seconds left to pay countdown function]]
	function(secondsLeft)

		--Called every second to report number of seconds left to pay
		print("Seconds left: ", secondsLeft);

	end,
	--[[Transaction successful/failed function]]
	function(success)

		--Called after transaction is received or after timeout for receiving payment from customer
		print("TX success: ",success);

	end,
	--[[Vend success/failed function]]
	function(checkTxUrl)

		--Called after receiving either vend success or vend failed from VMC
		if checkTxUrl==nil then
			print("Vend success");
		else
			print("Vend failed, you can check your refund transaction here: ",checkTxUrl);
		end

	end
);


--Don't forget about uv event loop :)
while true do
	uv.run();
end
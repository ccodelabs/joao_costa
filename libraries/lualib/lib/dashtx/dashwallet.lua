local openssl = require'openssl'
local pkey = openssl.pkey
local bn = openssl.bn;
local digest = openssl.digest;
local base58 = require 'dashtx.base58';
local bit = require 'dashtx.bit';
require "io";

local sha256 = digest.get("sha256");
local ripemd160 = digest.get("ripemd160");

local module = {};

local privateKey = nil;

local TX_VERSION = 0x02;

local function tohex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

local function fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

local function generateWallet()

    local nec =  {'ec','secp256k1'};
    privateKey = pkey.new(unpack(nec));

    local f = io.open("wallet","w");
    if f~=nil then
    	f:write(privateKey:export());
    	f:close();
    end

end

local function toCompactSizeInt(number)
	if number<=253 then
		return string.char(number);
	end
	if number<=0xFFFF then
		return string.char(
			0xFD,
		    bit.band(number, 0xff),
		    bit.band(bit.brshift(number, 8), 0xff)
		);
	end
	if number<=0xFFFFFFFF then
		return string.char(
			0xFE,
		    bit.band(number, 0xff),
		    bit.band(bit.brshift(number, 8), 0xff),
		    bit.band(bit.brshift(number, 16), 0xff),
		    bit.band(bit.brshift(number, 24), 0xff)
		);
	end
	if number<=0xFFFFFFFFFFFFFFFF then
		return string.char(
			0xFF,
		    bit.band(number, 0xff),
		    bit.band(bit.brshift(number, 8), 0xff),
		    bit.band(bit.brshift(number, 16), 0xff),
		    bit.band(bit.brshift(number, 24), 0xff),
		    bit.band(bit.brshift(number, 32), 0xff),
		    bit.band(bit.brshift(number, 40), 0xff),
		    bit.band(bit.brshift(number, 48), 0xff),
		    bit.band(bit.brshift(number, 56), 0xff)
		);
	end
end

local function isHighSsig(signature)
	--DER format signature
	if signature:byte(1)~=0x30 then
		return true;
	end
	local sigLen = signature:byte(2);
	local rLen = signature:byte(4);
	local r = signature:sub(5,4+rLen);
	local sLen = signature:byte(6+rLen);
	local s = signature:sub(7+rLen,6+rLen+sLen);

	if sLen==0x21 and s:byte(1)==0x00 then
		return true;
	end

	return false;

end

function module.getPublicKey()
	local pub1 = pkey.get_public(privateKey);

	local strX = bn.totext(pub1:parse().ec:parse(true).x);
	local strY = bn.totext(pub1:parse().ec:parse(true).y);

	while #strX<32 do
		strX = string.char(0x00)..strX;
	end
	while #strY<32 do
		strY = string.char(0x00)..strY;
	end
	local lastYByte = string.byte(strY,32);
	if math.fmod(lastYByte, 2)==0 then
		strX = string.char(0x02)..strX;
	else
		strX = string.char(0x03)..strX;
	end

	return strX;
end

function module.getAddress()
	local pub1 = pkey.get_public(privateKey);

	local strX = bn.totext(pub1:parse().ec:parse(true).x);
	local strY = bn.totext(pub1:parse().ec:parse(true).y);

	while #strX<32 do
		strX = string.char(0x00)..strX;
	end
	while #strY<32 do
		strY = string.char(0x00)..strY;
	end
	local lastYByte = string.byte(strY,32);
	if math.fmod(lastYByte, 2)==0 then
		strX = string.char(0x02)..strX;
	else
		strX = string.char(0x03)..strX;
	end
	local hashed = ripemd160:digest(sha256:digest(strX));
	hashed = string.char(0x4c)..hashed;
	local checksum = sha256:digest(sha256:digest(hashed));
	local address = base58.encode_base58(hashed..checksum:sub(1,4)):reverse();

	return address;
end

function module.generateTx(utxo, utxoNum, prevPubKeyScript, toAddress, satAmount)

	--Check utxo
	if utxo==nil then
		print("UTXO can't be nil!");
		return;
	end

	if #utxo~=64 then
		print("UTXO must be 64 character hexadecimal string!");
		return;
	end

	--Check utxoNum
	if utxoNum==nil then
		print("UTXO number can't be nil!");
		return;
	end

	--Check prevPubKeyScript
	if prevPubKeyScript==nil then
		print("prevPubKeyScript can't be nil!");
		return; 
	end
	prevPubKeyScript = fromhex(prevPubKeyScript);

	--Check address
	if toAddress==nil then
		print("Address can't be nil!");
		return;
	end

	local binAddress = base58.decode_base58(toAddress:reverse());
	if #binAddress~=25 then
		print("Address is too short!");
		return;
	end

	local version = binAddress:byte(1);
	local checksum = binAddress:sub(22,25);
	local hashedPubKey = binAddress:sub(2,21);

	if version~=0x4c then
		print("Address is not valid dash address!");
		return;
	end

	local calculatedChecksum = sha256:digest(sha256:digest(string.char(version)..hashedPubKey));

	if calculatedChecksum:sub(1,4)~=checksum then
		print("Address checksum failed!");
		return;
	end

	local txVersion = string.char(
		TX_VERSION,
		0x00,
		0x00,
		0x00
	);

	local inputs = string.char(1)..fromhex(utxo):reverse();
	inputs = inputs..string.char(
	    bit.band(utxoNum, 0xff),
	    bit.band(bit.brshift(utxoNum, 8), 0xff),
	    bit.band(bit.brshift(utxoNum, 16), 0xff),
	    bit.band(bit.brshift(utxoNum, 24), 0xff)
	);

	--script goes here!

	local inputSeqNum = string.char(0xff, 0xff, 0xff, 0xff);

	local outputsLen = string.char(0x01);

	local satAmount = string.char(
	    bit.band(satAmount, 0xff),
	    bit.band(bit.brshift(satAmount, 8), 0xff),
	    bit.band(bit.brshift(satAmount, 16), 0xff),
	    bit.band(bit.brshift(satAmount, 24), 0xff),
	    bit.band(bit.brshift(satAmount, 32), 0xff),
	    bit.band(bit.brshift(satAmount, 40), 0xff),
	    bit.band(bit.brshift(satAmount, 48), 0xff),
	    bit.band(bit.brshift(satAmount, 56), 0xff)
	);

	local pubKeyScriptLen = string.char(25);

	--Add pubkey script
	local pubKeyScript = string.char(
		0x76, --OP_DUP
		0xa9, --OP_HASH160
		0x14  --OP_PUSH20
	);
	pubKeyScript = pubKeyScript..hashedPubKey; --Public key hash
	pubKeyScript = pubKeyScript..string.char(
		0x88, --OP_EQUALVERIFY
		0xac  --OP_CHECKSIG
	);

	local lockTime = string.char(
		0x00,
		0x00,
		0x00,
		0x00
	);	

	local hashCodeType = string.char(
		0x01,
		0x00,
		0x00,
		0x00
	);

	--Try generate scriptSig
	local doubleSha256 = sha256:digest(sha256:digest(
		txVersion..
		inputs..
		string.char(#prevPubKeyScript)..
		prevPubKeyScript..
		inputSeqNum..
		outputsLen..
		satAmount..
		pubKeyScriptLen..
		pubKeyScript..
		lockTime..
		hashCodeType
	));

	local scriptSig;

	while scriptSig==nil or isHighSsig(scriptSig) do
		scriptSig = privateKey:parse().ec:sign(doubleSha256)..string.char(0x01)
	end

	local scriptPubKey = module.getPublicKey();

	local script = string.char(#scriptSig)..scriptSig..string.char(#scriptPubKey)..scriptPubKey;
	local scriptLen = toCompactSizeInt(#script);

	local tx = txVersion..
				inputs..
				scriptLen..
				script..
				inputSeqNum..
				outputsLen..
				satAmount..
				pubKeyScriptLen..
				pubKeyScript..
				lockTime;

	local txId = sha256:digest(sha256:digest(tx));

	return tohex(tx), tohex(txId:reverse());

end

local f = io.open("wallet","r");
if f~=nil then
	local str = f:read("*all");
	f:close();
	if str~=nil then
		privateKey = pkey.read(str, true, "pem");
		if privateKey~=nil then
			return module;
		end
	end
end
generateWallet();

return module;
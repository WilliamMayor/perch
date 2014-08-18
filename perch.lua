SLASH_PERCH1 = '/perch'
DIALOG_PERCH = 'perch_dialog'

local FormatMoney, GetBidPrice, ShouldBuy, ShouldBid, Buy, Bid, Purchase, Scan, RegisterUpdate, Test

function FormatMoney(money)
    local ret = ""
    local gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD))
    local silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER)
    local copper = mod(money, COPPER_PER_SILVER)
    if gold > 0 then
        ret = gold .. "g"
    end
    if silver > 0 or gold > 0 then
        ret = ret .. silver .. "s"
    end
    ret = ret .. copper .. "c"
    return ret;
end

function GetBidPrice(minBid, increment, bidAmount)
    if (bidAmount > 0) then
        return bidAmount + increment
    end
    return minBid
end

function ShouldBuy(vendorValue, buyout)
    return (vendorValue > buyout and buyout > 0)
end

function ShouldBid(vendorValue, minBid, increment, bidAmount)
    return vendorValue > GetBidPrice(minBid, increment, bidAmount)
end

function Buy(item, item_link, buyout, vendor)
    return {
        text = "Buy "..item_link.." for "..FormatMoney(buyout).." and vendor for "..FormatMoney(vendor).."? Profit is",
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            PlaceAuctionBid("list", item, buyout);
        end,
        OnShow = function(self)
            MoneyFrame_Update(self.moneyFrame, vendor - buyout);
        end,
        timeout = 0,
        whileDead = false,
        hideOnEscape = true,
        hasMoneyFrame = 1,
        enterClicksFirstButton = true,
    }
end

function Bid(item, item_link, bid, vendor)
    return {
        text = "Bid on "..item_link.." at "..FormatMoney(bid).." and vendor for "..FormatMoney(vendor).."? Profit is",
        button1 = YES,
        button2 = NO,
        OnAccept = function()
            PlaceAuctionBid("list", item, bid)
        end,
        OnShow = function(self)
            MoneyFrame_Update(self.moneyFrame, vendor - bid);
        end,
        timeout = 0,
        whileDead = false,
        hideOnEscape = true,
        hasMoneyFrame = 1,
        enterClicksFirstButton = true,
    }
end

function Purchase(purchases)
    if next(purchases) == nil then
        print("Perch: Complete")
        return
    end
    purchase = table.remove(purchases, 1)
    purchase['OnHide'] = function(self)
        Purchase(self.data)
    end
    StaticPopupDialogs[DIALOG_PERCH] = purchase
    local dialog = StaticPopup_Show(DIALOG_PERCH)
    if (dialog) then
        dialog.data = purchases
    end
end

function Scan()
    local batch, _ = GetNumAuctionItems("list")
    if (batch == 0) then
        print("Perch: Error: You must have the AH window open to perch.")
        return
    end
    print("Perch: Found " .. batch .. " items")
    purchases = {}
    for index = batch, 1, -1 do
        if index % 10000 == 0 then
            print("Perch: At item " .. batch - index)
            PlaySound("MapPing", "master");
        end
        local name, _, count, _, _, _, _, minBid, minIncrement, buyoutPrice, bidAmount, highBidder, _, _, _, saleStatus, itemId, hasAllInfo = GetAuctionItemInfo("list", index);
        local item_link = GetAuctionItemLink("list", index)
        if item_link ~= nil then
            local _, _, _, _, _, _, _, _, _, _, vendorValue = GetItemInfo(itemId)
            if (highBidder == nil and saleStatus == 0) then
                if (ShouldBuy(vendorValue * count, buyoutPrice)) then
                    print("Buy " .. item_link .. " x " .. count .. " @ " .. FormatMoney(buyoutPrice) .. ", vendor for " .. FormatMoney(vendorValue * count))
                    table.insert(purchases, Buy(index, item_link, buyoutPrice, vendorValue * count))
                elseif (ShouldBid(vendorValue * count, minBid, minIncrement, bidAmount)) then
                    print("Bid on " .. item_link .. " x " .. count .. " @ " .. FormatMoney(GetBidPrice(minBid, minIncrement, bidAmount)) .. ", vendor for " .. FormatMoney(vendorValue * count))
                    table.insert(purchases, Bid(index, item_link, GetBidPrice(minBid, minIncrement, bidAmount), vendorValue * count))
                end
            end
        end
    end
    PlaySound("QUESTCOMPLETED", "master");
    Purchase(purchases)
end

function RegisterUpdate()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event=="AUCTION_ITEM_LIST_UPDATE" then
            frame:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
            print("Perch: Running full scan")
            Scan()
        end
    end);
end

function SlashCmdList.PERCH(msg, editbox)
    if msg == "test" then
        Test()
        return
    end
    local canQuery, canQueryAll = CanSendAuctionQuery();
    if (canQueryAll) then
        RegisterUpdate()
        QueryAuctionItems("",nil,nil,0,0,0,0,0,0,true)
    elseif (canQuery) then
        print("Perch: Scanning current AH list (i.e. what you see in the Browse tab)")
        Scan()
    else
        print("Perch: You cannot fully perch your AH more than once every 15 mins, you cannot perch anything more than 3 times a second.")
    end
end

function Test()
    if "1g1s1c" ~= FormatMoney(10101) then print "Perch: Test: Failed - FormatMoney(10101)" end
    if "1s1c" ~= FormatMoney(101) then print "Perch: Test: Failed - FormatMoney(101)" end
    if "1c" ~= FormatMoney(1) then print "Perch: Test: Failed - FormatMoney(1)" end
    if "1g0s1c" ~= FormatMoney(10001) then print "Perch: Test: Failed - FormatMoney(10001)" end
    if "1g1s0c" ~= FormatMoney(10100) then print "Perch: Test: Failed - FormatMoney(10100)" end
    if "1g0s0c" ~= FormatMoney(10000) then print "Perch: Test: Failed - FormatMoney(10000)" end
    
    if 1 ~= GetBidPrice(1, 5, 0) then print "Perch: Test: Failed - GetBidPrice(1,5,0)" end
    if 2 ~= GetBidPrice(1, 1, 1) then print "Perch: Test: Failed - GetBidPrice(1,1,1)" end
    
    if false == ShouldBuy(5,3) then print "Perch: Test: Failed - ShouldBuy(5,3)" end
    if true == ShouldBuy(3,5) then print "Perch: Test: Failed - ShouldBuy(3,5)" end
    
    if false == ShouldBid(5,3,1,0) then print "Perch: Test: Failed - ShouldBid(5,3,1,0)" end
    if true == ShouldBid(3,5,1,0) then print "Perch: Test: Failed - ShouldBid(3,5,1,0)" end
end

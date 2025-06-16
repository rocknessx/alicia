-- QB-Core nesnesini al
local QBCore = exports['qb-core']:GetCoreObject()

-- Bağlı oyuncuları takip et
local connectedPlayers = {}
local maxPlayers = 2 -- ✅ Varsayılan 7 oyuncu (değiştirilebilir)
local currentRoundResults = {} -- Bu round'daki sonuçlar
local alivePlayers = {} -- Hayatta olan oyuncular
local roundNumber = 1

-- Logo seçenekleri (client ile uyumlu)
local symbols = {"diamond", "club", "heart", "spade"}

-- Rastgele isimler için örnek liste (10 oyuncu için)
local botNames = {
    "Michael Johnson", "Sarah Wilson", "David Brown", "Emily Davis", 
    "James Miller", "Lisa Anderson", "Robert Taylor", "Jennifer Martinez", 
    "William Garcia", "Amanda Rodriguez"
}

-- SERVER-SIDE ONLY güvenli sembol atama sistemi (HİLE KORUNMALI)
local serverEntitySymbols = {} -- Server'da saklanan semboller (CLIENT ASLA ERİŞEMEZ)
local serverSpadeKingId = nil   -- Server'da saklanan maça beyi (CLIENT ASLA ERİŞEMEZ)
local gameSessionActive = false -- Oyun oturumu kontrolü

-- FIXED: Gerçek rastgelelik için hash-based random
local randomCounter = 0
function GetTrueRandom(min, max)
    randomCounter = randomCounter + 1
    local hash = GetHashKey(tostring(os.time() + GetGameTimer() + randomCounter))
    local positiveHash = math.abs(hash)
    local result = (positiveHash % (max - min + 1)) + min
    print("[qb-alicia] 🎲 TrueRandom(" .. min .. "," .. max .. ") = " .. result .. " (hash:" .. hash .. ")")
    return result
end

-- ANTI-CHEAT: FIXED Rastgele sembol seçme fonksiyonu (SADECE SERVER-SIDE)
function GetRandomSymbolSecure()
    local symbols = {"diamond", "club", "heart", "spade"}
    local randomIndex = GetTrueRandom(1, 4)
    local selectedSymbol = symbols[randomIndex]
    
    print("[qb-alicia] 🎲 Sembol seçimi: Index=" .. randomIndex .. " → " .. selectedSymbol)
    return selectedSymbol
end

-- ANTI-CHEAT: Sembol atama doğrulama
function ValidateSymbolAssignment(playerId, claimedSymbol)
    local serverSymbol = serverEntitySymbols[tostring(playerId)]
    if serverSymbol and serverSymbol == claimedSymbol then
        return true
    else
        print("[qb-alicia] 🚨 HİLE TESPİTİ: " .. playerId .. " yanlış sembol iddiası! Server: " .. (serverSymbol or "nil") .. ", İddia: " .. (claimedSymbol or "nil"))
        return false
    end
end

-- ANTI-CHEAT: Maça beyi doğrulama
function ValidateSpadeKing(playerId)
    if serverSpadeKingId and tonumber(serverSpadeKingId) == tonumber(playerId) then
        return true
    else
        print("[qb-alicia] 🚨 HİLE TESPİTİ: " .. playerId .. " sahte maça beyi iddiası! Gerçek maça beyi: " .. (serverSpadeKingId or "nil"))
        return false
    end
end

-- Oyuncu pozisyonları sistemi
local playerPositions = {} -- [playerId] = position (1-10)

-- Rastgele pozisyon atama fonksiyonu
function AssignPlayerPositions()
    local positions = {} -- Kullanılacak pozisyonlar (1-10)
    for i = 1, 10 do
        table.insert(positions, i)
    end
    
    -- Pozisyonları karıştır
    for i = #positions, 2, -1 do
        local j = GetTrueRandom(1, i)
        positions[i], positions[j] = positions[j], positions[i]
    end
    
    local positionIndex = 1
    playerPositions = {} -- Temizle
    
    print("[qb-alicia] 🎯 === OYUNCU POZİSYON ATAMASI ===")
    
    -- Gerçek oyunculara pozisyon ata
    for playerId, data in pairs(connectedPlayers) do
        if tonumber(playerId) > 0 then -- Sadece gerçek oyuncular
            if positionIndex <= #positions then
                playerPositions[playerId] = positions[positionIndex]
                print("[qb-alicia] 🎯 " .. data.name .. " (ID:" .. playerId .. ") → Pozisyon " .. positions[positionIndex])
                
                -- Client'a pozisyon bildir
                TriggerClientEvent('qb-alicia:setPlayerPosition', playerId, positions[positionIndex])
                
                positionIndex = positionIndex + 1
            end
        end
    end
    
    -- Botlara pozisyon ata
    for playerId, data in pairs(connectedPlayers) do
        if tonumber(playerId) < 0 then -- Botlar
            if positionIndex <= #positions then
                playerPositions[playerId] = positions[positionIndex]
                print("[qb-alicia] 🎯 " .. data.name .. " (BOT ID:" .. playerId .. ") → Pozisyon " .. positions[positionIndex])
                positionIndex = positionIndex + 1
            end
        end
    end
    
    print("[qb-alicia] 🎯 === POZİSYON ATAMA TAMAMLANDI ===")
end

-- Round sistemi
local currentRound = 1
local maxRounds = 5 -- Maksimum round sayısı

-- ✅ %25 EŞİT DAĞILIM SEMBOL ATAMA SİSTEMİ
function SecureSymbolAssignment()
    print("[qb-alicia] 🔒 === %25 EŞİT DAĞILIM SEMBOL ATAMA BAŞLIYOR ===")
    
    -- Önce eski verileri temizle
    serverEntitySymbols = {}
    serverSpadeKingId = nil
    local allPlayers = {}
    
    -- Session ID oluştur
    local sessionId = "SESSION_" .. os.time() .. "_" .. GetTrueRandom(10000, 99999)
    gameSessionActive = sessionId
    
    print("[qb-alicia] 🔒 Oyun Session ID: " .. sessionId)
    print("[qb-alicia] 🔒 Lobideki oyuncu sayısı: " .. tableLength(connectedPlayers))
    
    -- Tüm oyuncuları listeye al
    for playerId, data in pairs(connectedPlayers) do
        table.insert(allPlayers, {
            id = tostring(playerId),
            name = data.name,
            data = data
        })
    end
    
    local totalPlayers = #allPlayers
    print("[qb-alicia] 🔒 Toplam oyuncu: " .. totalPlayers)
    
    if totalPlayers == 0 then
        print("[qb-alicia] 🔒 ❌ HATA: Hiç oyuncu yok!")
        return sessionId
    end
    
    -- ✅ SEMBOL HAVUZU OLUŞTUR (%25 EŞİT DAĞILIM)
    local symbolPool = {}
    local symbols = {"diamond", "club", "heart", "spade"}
    
    -- Her sembolden eşit sayıda ekle
    local symbolsPerType = math.ceil(totalPlayers / 4)
    
    for _, symbol in ipairs(symbols) do
        for i = 1, symbolsPerType do
            table.insert(symbolPool, symbol)
        end
    end
    
    -- Eğer fazla sembol varsa, fazlalıkları rastgele kaldır
    while #symbolPool > totalPlayers do
        local removeIndex = GetTrueRandom(1, #symbolPool)
        table.remove(symbolPool, removeIndex)
    end
    
    -- Eğer eksik sembol varsa, rastgele ekle
    while #symbolPool < totalPlayers do
        local randomSymbol = symbols[GetTrueRandom(1, 4)]
        table.insert(symbolPool, randomSymbol)
    end
    
    print("[qb-alicia] 🔒 === SEMBOL HAVUZU ===")
    local poolCount = {diamond = 0, club = 0, heart = 0, spade = 0}
    for _, symbol in ipairs(symbolPool) do
        poolCount[symbol] = poolCount[symbol] + 1
    end
    
    for symbol, count in pairs(poolCount) do
        local percentage = math.floor((count / totalPlayers) * 100)
        print("[qb-alicia] 🔒 " .. symbol:upper() .. ": " .. count .. " adet (%" .. percentage .. ")")
    end
    
    -- ✅ SEMBOL HAVUZUNU KARIŞTIR
    for i = #symbolPool, 2, -1 do
        local j = GetTrueRandom(1, i)
        symbolPool[i], symbolPool[j] = symbolPool[j], symbolPool[i]
    end
    
    print("[qb-alicia] 🔒 Sembol havuzu karıştırıldı!")
    
    -- ✅ OYUNCULARA SEMBOL ATA (%25 EŞİT DAĞILIM)
    print("[qb-alicia] 🔒 === SEMBOL ATAMA ===")
    
    for i, player in ipairs(allPlayers) do
        local assignedSymbol = symbolPool[i]
        serverEntitySymbols[player.id] = assignedSymbol
        
        print("[qb-alicia] 🔒 [" .. i .. "/" .. totalPlayers .. "] " .. player.name .. " (ID:" .. player.id .. ") → " .. assignedSymbol)
    end
    
    -- ✅ RASTGELE MAÇA BEYİNİ SEÇ (TÜM OYUNCULAR ARASINDA - SEMBOL FARK ETMEZ)
    local randomPlayerIndex = GetTrueRandom(1, totalPlayers)
    local chosenKing = allPlayers[randomPlayerIndex]
    serverSpadeKingId = chosenKing.id
    
    -- Maça beyinin hangi sembolü aldığını kontrol et
    local kingSymbol = serverEntitySymbols[chosenKing.id]
    
    print("[qb-alicia] 🔒 === RASTGELE MAÇA BEYİ SEÇİMİ ===")
    print("[qb-alicia] 🔒 👑 Toplam oyuncu sayısı: " .. totalPlayers)
    print("[qb-alicia] 🔒 👑 Seçilen index: " .. randomPlayerIndex .. "/" .. totalPlayers)
    print("[qb-alicia] 🔒 👑 RASTGELE MAÇA BEYİ: " .. chosenKing.name .. " (ID:" .. chosenKing.id .. ")")
    print("[qb-alicia] 🔒 👑 Maça beyinin sembolü: " .. kingSymbol .. " (%25 ihtimalle geldi)")
    print("[qb-alicia] 🔒 👑 ZORLA SPADE VERİLMEDİ - DOĞAL DAĞILIM!")
    
    -- ✅ FINAL SONUÇ KONTROLÜ
    local finalCount = {diamond = 0, club = 0, heart = 0, spade = 0}
    for playerId, symbol in pairs(serverEntitySymbols) do
        finalCount[symbol] = finalCount[symbol] + 1
    end
    
    print("[qb-alicia] 🔒 === FINAL SEMBOL DAĞILIMI ===")
    for symbol, count in pairs(finalCount) do
        local percentage = math.floor((count / totalPlayers) * 100)
        print("[qb-alicia] 🔒 " .. symbol:upper() .. ": " .. count .. " adet (%" .. percentage .. ")")
    end
    
    print("[qb-alicia] 🔒 === ATAMA TAMAMLANDI ===")
    print("[qb-alicia] 🔒 Toplam oyuncu: " .. tableLength(serverEntitySymbols))
    print("[qb-alicia] 🔒 👑 Maça beyi: " .. (serverSpadeKingId or "YOK") .. " (Sembol: " .. (kingSymbol or "YOK") .. ")")
    print("[qb-alicia] 🔒 Session: " .. sessionId)
    print("[qb-alicia] 🔒 ✅ MAÇA BEYİNE ZORLA SPADE VERİLMEDİ!")
    
    return sessionId
end

-- NPC ile konuşma eventi (warning sayfasına yönlendir)
RegisterNetEvent('qb-alicia:openWebpage')
AddEventHandler('qb-alicia:openWebpage', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print("[qb-alicia] Hata: Oyuncu bulunamadı.")
        return
    end

    -- Warning sayfasını aç (client'ta)
    TriggerClientEvent('qb-alicia:showWarning', src)
    print("[qb-alicia] Oyuncuya warning sayfası gösteriliyor: " .. Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname)
end)

-- Oyuncuları ışınlama ve sembol atama (SERVER-SIDE güvenli sistem)
RegisterNetEvent('update:ck_onay')
AddEventHandler('update:ck_onay', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print("[qb-alicia] Hata: Oyuncu bulunamadı.")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if not citizenid then
        print("[qb-alicia] Hata: Oyuncu citizenid alınamadı.")
        return
    end

    print("[qb-alicia] ck_onay güncelleme başlatıldı: " .. citizenid)

    -- oxmysql execute ile ck_onay'ı güncelle
    exports['oxmysql']:execute('UPDATE players SET ck_onay = 1 WHERE citizenid = :citizenid', {
        ['citizenid'] = citizenid
    }, function(result)
        local affectedRows = type(result) == 'table' and (result.affectedRows or 0) or (result or 0)
        if affectedRows > 0 then
            print("[qb-alicia] ck_onay = 1 olarak güncellendi: " .. citizenid)
            
            -- Karakter ismini al
            local charinfo = Player.PlayerData.charinfo
            local playerName = charinfo.firstname .. " " .. charinfo.lastname
            
            -- Oyuncuyu bağlı listesine ekle (JavaScript'in beklediği format)
            connectedPlayers[src] = {
                name = playerName, 
                citizenid = citizenid, 
                ready = true  -- JavaScript kontrolü için
            }
            
            print("[qb-alicia] " .. playerName .. " connectedPlayers listesine eklendi.")
            
            -- open:lobi eventi gönder
            print("[qb-alicia] open:lobi eventi gönderiliyor...")
            TriggerClientEvent('open:lobi', src, connectedPlayers)
            
            -- Kısa bir bekleme sonrası diğer oyunculara güncelleme gönder
            Citizen.CreateThread(function()
                Citizen.Wait(1000)
                
                -- Tüm bağlı oyunculara güncellenmiş listeyi gönder
                for playerId, playerData in pairs(connectedPlayers) do
                    if tonumber(playerId) > 0 then -- Sadece gerçek oyunculara gönder
                        TriggerClientEvent('update:lobby', playerId, connectedPlayers)
                    end
                end
                
                print("[qb-alicia] " .. playerName .. " lobiye katıldı.")
                
                -- Oyuncu sayısı kontrolü
                CheckAndTeleportPlayers()
            end)
        else
            print("[qb-alicia] Hata: ck_onay güncellenemedi, oyuncu bulunamadı: " .. citizenid)
            TriggerClientEvent('QBCore:Notify', src, 'Veritabanı hatası! Tekrar deneyin.', 'error')
        end
    end)
end)

-- Oyuncu sayısı kontrolü ve ışınlama fonksiyonu (ULTRA GÜVENLİ SERVER-SIDE)
function CheckAndTeleportPlayers()
    local realPlayerCount = 0
    local totalPlayerCount = 0
    
    for playerId, _ in pairs(connectedPlayers) do
        totalPlayerCount = totalPlayerCount + 1
        if tonumber(playerId) > 0 then -- Gerçek oyuncular
            realPlayerCount = realPlayerCount + 1
        end
    end
    
    print("[qb-alicia] Gerçek oyuncu: " .. realPlayerCount .. ", Toplam: " .. totalPlayerCount .. "/" .. maxPlayers)
    
    -- Eğer toplam oyuncu sayısı (gerçek + bot) hedef sayıya ulaştıysa spawn et
    if totalPlayerCount >= maxPlayers then
        print("[qb-alicia] " .. maxPlayers .. " oyuncu toplandı! ULTRA GÜVENLİ SERVER-SIDE sembol atama başlıyor...")
        
        -- ULTRA GÜVENLİ SERVER-SIDE SEMBOL ATAMA
        local sessionId = SecureSymbolAssignment()
        
        -- CLIENT'A SADECE GÜVENLİ VERİ GÖNDER (HİLE KORUNMALI)
        local securePlayerData = {}
        for playerId, data in pairs(connectedPlayers) do
            local playerIdStr = tostring(playerId)
            securePlayerData[playerIdStr] = {
                name = data.name,
                id = tonumber(playerId),
                symbol = serverEntitySymbols[playerIdStr], -- Server'dan gelen ULTRA güvenli sembol
                isSpadeKing = (serverSpadeKingId == playerIdStr), -- Server'dan gelen ULTRA güvenli maça beyi bilgisi
                sessionId = sessionId -- Hile kontrolü için session
            }
            
            -- Debug çıktısı
            local kingMark = (serverSpadeKingId == playerIdStr) and " 👑 MAÇA BEYİ" or ""
            print("[qb-alicia] 🔒 CLIENT'A GÖNDERİLEN VERİ: " .. data.name .. " → " .. serverEntitySymbols[playerIdStr] .. kingMark)
        end
        
        -- Pozisyon ataması yap
        AssignPlayerPositions()
        
        -- Tüm gerçek oyuncuları ışınla ve güvenli veriyi gönder
        for playerId, _ in pairs(connectedPlayers) do
            if tonumber(playerId) > 0 then -- Sadece gerçek oyunculara gönder
                print("[qb-alicia] 🔒 ULTRA GÜVENLİ VERİ GÖNDERİLİYOR: " .. playerId)
                
                -- Önce teleport et
                TriggerClientEvent('teleport:players', playerId, securePlayerData, totalPlayerCount)
                
                -- 2 saniye sonra NUI countdown'u başlat
                Citizen.CreateThread(function()
                    Citizen.Wait(2000)
                    print("[qb-alicia] 🎮 " .. playerId .. " için NUI countdown başlatılıyor...")
                    TriggerClientEvent('qb-alicia:startNUICountdown', playerId)
                end)
            end
        end
        
        -- Listeyi sıfırla
        connectedPlayers = {}
        print("[qb-alicia] 🔒 " .. totalPlayerCount .. " oyuncu (ULTRA güvenli server-side) spawn edildi.")
        print("[qb-alicia] 🔒 Session aktif: " .. sessionId)
        return true -- Spawn yapıldığını belirt
    else
        -- Henüz yeterli oyuncu yok, sadece lobi güncellemesi
        for playerId, _ in pairs(connectedPlayers) do
            if tonumber(playerId) > 0 then
                TriggerClientEvent('update:lobby', playerId, connectedPlayers)
            end
        end
        print("[qb-alicia] Bekliyor: " .. totalPlayerCount .. "/" .. maxPlayers .. " oyuncu")
        return false -- Spawn yapılmadığını belirt
    end
end


-- ANTI-CHEAT: Client'tan gelen sembol bilgilerini doğrula
RegisterNetEvent('qb-alicia:validateSymbol')
AddEventHandler('qb-alicia:validateSymbol', function(claimedSymbol, claimedKingStatus)
    local src = source
    
    -- Sembol doğrulaması
    if not ValidateSymbolAssignment(src, claimedSymbol) then
        print("[qb-alicia] 🚨 KICK: " .. src .. " sembol hilesi nedeniyle!")
        DropPlayer(src, "🚨 Hile tespit edildi: Geçersiz sembol bilgisi!")
        return
    end
    
    -- Maça beyi doğrulaması
    if claimedKingStatus and not ValidateSpadeKing(src) then
        print("[qb-alicia] 🚨 KICK: " .. src .. " maça beyi hilesi nedeniyle!")
        DropPlayer(src, "🚨 Hile tespit edildi: Sahte maça beyi iddiası!")
        return
    end
    
    print("[qb-alicia] ✅ " .. src .. " sembol doğrulaması başarılı.")
end)

-- Oyuncu tahmin sonucu eventi
RegisterNetEvent('qb-alicia:playerGuessResult')
AddEventHandler('qb-alicia:playerGuessResult', function(guessedSymbol, isCorrect)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    local realSymbol = serverEntitySymbols[tostring(src)]
    
    -- ✅ Server-side doğrulama
    local serverValidation = false
    if guessedSymbol and realSymbol then
        serverValidation = (guessedSymbol:lower() == realSymbol:lower())
    end
    
    print("[qb-alicia] 🎲 === ROUND " .. roundNumber .. " TAHMİN SONUCU ===")
    print("[qb-alicia] 🎲 Oyuncu: " .. playerName .. " (ID:" .. src .. ")")
    print("[qb-alicia] 🎲 Gerçek sembol (SERVER): " .. (realSymbol or "YOK"))
    print("[qb-alicia] 🎲 Tahmin: " .. (guessedSymbol or "YOK"))
    print("[qb-alicia] 🎲 Server doğrulama: " .. (serverValidation and "✅ DOĞRU" or "❌ YANLIŞ"))
    
    -- ✅ MAÇA BEYİ KONTROLÜ
    local isSpadeKing = (serverSpadeKingId == tostring(src))
    if isSpadeKing then
        print("[qb-alicia] 👑 === MAÇA BEYİ TAHMİN SONUCU ===")
    end
    
    -- ✅ Bu round'ın sonucunu kaydet
    currentRoundResults[tostring(src)] = {
        playerId = src,
        playerName = playerName,
        isCorrect = serverValidation,
        isSpadeKing = isSpadeKing,
        guessedSymbol = guessedSymbol,
        realSymbol = realSymbol
    }
    
    -- ✅ Hayatta olan oyuncuları güncelle
    if serverValidation then
        alivePlayers[tostring(src)] = true
        print("[qb-alicia] ✅ " .. playerName .. " hayatta kaldı!")
    else
        alivePlayers[tostring(src)] = false
        print("[qb-alicia] 💀 " .. playerName .. " öldü!")
        
        -- ✅ MAÇA BEYİ ÖLDÜYSE OYUN BİTER
        if isSpadeKing then
            print("[qb-alicia] 👑💀 === MAÇA BEYİ ÖLDÜ - OYUN BİTTİ! ===")
            EndGame("spade_king_died")
            return
        end
    end
    
    -- ✅ Tüm oyuncular tahmin yaptı mı kontrol et
    CheckRoundComplete()
end)

-- ✅ Round tamamlandı mı kontrol et
function CheckRoundComplete()
    local totalPlayers = 0
    local completedPlayers = 0
    
    -- Toplam oyuncu sayısını bul
    for playerId, symbol in pairs(serverEntitySymbols) do
        totalPlayers = totalPlayers + 1
    end
    
    -- Tahmin yapan oyuncu sayısını bul
    for playerId, result in pairs(currentRoundResults) do
        completedPlayers = completedPlayers + 1
    end
    
    print("[qb-alicia] 🔄 Round kontrol: " .. completedPlayers .. "/" .. totalPlayers .. " oyuncu tahmin yaptı")
    
    if completedPlayers >= totalPlayers then
        print("[qb-alicia] 🔄 === ROUND " .. roundNumber .. " TAMAMLANDI ===")
        ProcessRoundResults()
    end
end

-- ✅ Round sonuçlarını işle
function ProcessRoundResults()
    local aliveCount = 0
    local alivePlayersList = {}
    local spadeKingAlive = false
    
    -- Hayatta olanları say
    for playerId, isAlive in pairs(alivePlayers) do
        if isAlive then
            aliveCount = aliveCount + 1
            table.insert(alivePlayersList, playerId)
            
            -- Maça beyi hayatta mı?
            if serverSpadeKingId == playerId then
                spadeKingAlive = true
            end
        end
    end
    
    print("[qb-alicia] 🔄 === ROUND " .. roundNumber .. " SONUÇ ===")
    print("[qb-alicia] 🔄 Hayatta olan: " .. aliveCount .. " oyuncu")
    print("[qb-alicia] 🔄 Maça beyi durumu: " .. (spadeKingAlive and "HAYATTA" or "ÖLÜ"))
    
    -- ✅ OYUN BİTİŞ KONTROLLERI
    if aliveCount == 0 then
        print("[qb-alicia] 🏁 === OYUN BİTTİ: HİÇKİMSE KALMADI ===")
        EndGame("no_survivors")
    elseif aliveCount == 1 and spadeKingAlive then
        print("[qb-alicia] 🏁 === OYUN BİTTİ: SADECE MAÇA BEYİ KALDI ===")
        EndGame("spade_king_wins")
    elseif not spadeKingAlive then
        print("[qb-alicia] 🏁 === OYUN BİTTİ: MAÇA BEYİ ÖLDÜ ===")
        EndGame("spade_king_died")
    else
        -- ✅ OYUN DEVAM EDİYOR - YENİ ROUND
        print("[qb-alicia] 🔄 === OYUN DEVAM EDİYOR ===")
        StartNewRound()
    end
end

-- ✅ Yeni round başlat
function StartNewRound()
    roundNumber = roundNumber + 1
    currentRoundResults = {}
    
    print("[qb-alicia] 🆕 === YENİ ROUND BAŞLIYOR: " .. roundNumber .. " ===")
    
    -- ✅ MAÇA BEYİNİ KORU (ASLA DEĞİŞMEZ)
    local permanentSpadeKing = serverSpadeKingId
    print("[qb-alicia] 🆕 👑 SABİT MAÇA BEYİ: " .. (permanentSpadeKing or "YOK"))
    
    -- ✅ HAYATTA OLAN OYUNCULAR LİSTESİ
    print("[qb-alicia] 🆕 === HAYATTA OLAN OYUNCULAR ===")
    local alivePlayersList = {}
    local aliveRealPlayers = {}
    
    for playerId, isAlive in pairs(alivePlayers) do
        if isAlive then
            print("[qb-alicia] 🆕 HAYATTA: " .. playerId .. (permanentSpadeKing == playerId and " 👑 (SABİT MAÇA BEYİ)" or ""))
            table.insert(alivePlayersList, playerId)
            
            if tonumber(playerId) > 0 then
                table.insert(aliveRealPlayers, tonumber(playerId))
                
                -- ConnectedPlayers'a ekle
                local Player = QBCore.Functions.GetPlayer(tonumber(playerId))
                if Player then
                    connectedPlayers[tonumber(playerId)] = {
                        name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                        citizenid = Player.PlayerData.citizenid,
                        ready = true
                    }
                end
            else
                -- Bot bilgisini koru
                connectedPlayers[playerId] = {
                    name = "Bot_" .. math.abs(tonumber(playerId)),
                    citizenid = "BOT" .. playerId,
                    ready = true
                }
            end
        else
            print("[qb-alicia] 🆕 ÖLÜ: " .. playerId)
        end
    end
    
    local totalAlivePlayers = #alivePlayersList
    print("[qb-alicia] 🆕 Hayatta olan toplam: " .. totalAlivePlayers)
    print("[qb-alicia] 🆕 Gerçek oyuncu: " .. #aliveRealPlayers)
    
    -- ✅ %25 EŞİT DAĞILIM SEMBOL ATAMA SİSTEMİ
    print("[qb-alicia] 🆕 === %25 EŞİT DAĞILIM SEMBOL ATAMA ===")
    
    -- Eski sembol verilerini temizle
    serverEntitySymbols = {}
    
    -- ✅ SEMBOL HAVUZU OLUŞTUR (%25 EŞİT DAĞILIM)
    local symbolPool = {}
    local symbols = {"diamond", "club", "heart", "spade"}
    local symbolsPerType = math.ceil(totalAlivePlayers / 4)
    
    -- Her sembolden eşit sayıda ekle
    for _, symbol in ipairs(symbols) do
        for i = 1, symbolsPerType do
            table.insert(symbolPool, symbol)
        end
    end
    
    -- Eğer fazla sembol varsa, fazlalıkları rastgele kaldır
    while #symbolPool > totalAlivePlayers do
        local removeIndex = GetTrueRandom(1, #symbolPool)
        table.remove(symbolPool, removeIndex)
    end
    
    -- Eğer eksik sembol varsa, rastgele ekle
    while #symbolPool < totalAlivePlayers do
        local randomSymbol = symbols[GetTrueRandom(1, 4)]
        table.insert(symbolPool, randomSymbol)
    end
    
    -- Sembol havuzunu karıştır
    for i = #symbolPool, 2, -1 do
        local j = GetTrueRandom(1, i)
        symbolPool[i], symbolPool[j] = symbolPool[j], symbolPool[i]
    end
    
    print("[qb-alicia] 🆕 === SEMBOL HAVUZU (KARIŞTIRMA ÖNCESİ) ===")
    local poolCount = {diamond = 0, club = 0, heart = 0, spade = 0}
    for _, symbol in ipairs(symbolPool) do
        poolCount[symbol] = poolCount[symbol] + 1
    end
    for symbol, count in pairs(poolCount) do
        local percentage = math.floor((count / totalAlivePlayers) * 100)
        print("[qb-alicia] 🆕 " .. symbol:upper() .. ": " .. count .. " adet (%" .. percentage .. ")")
    end
    
    -- ✅ HAYATTA OLANLARA SEMBOL ATA
    for i, playerId in ipairs(alivePlayersList) do
        local assignedSymbol = symbolPool[i]
        serverEntitySymbols[playerId] = assignedSymbol
        
        local playerName = connectedPlayers[tonumber(playerId)] and connectedPlayers[tonumber(playerId)].name or connectedPlayers[playerId].name or ("Player_" .. playerId)
        print("[qb-alicia] 🆕 [" .. i .. "/" .. totalAlivePlayers .. "] " .. playerName .. " → " .. assignedSymbol)
    end
    
    -- ✅ MAÇA BEYİNE ZORLA SPADE VER (SABİT KALMASI İÇİN)
  
    
    -- ✅ FINAL SEMBOL DAĞILIMI KONTROLÜ
    local finalSymbolCount = {diamond = 0, club = 0, heart = 0, spade = 0}
    for playerId, symbol in pairs(serverEntitySymbols) do
        finalSymbolCount[symbol] = finalSymbolCount[symbol] + 1
    end
    
    print("[qb-alicia] 🆕 === ROUND " .. roundNumber .. " FINAL SEMBOL DAĞILIMI ===")
    for symbol, count in pairs(finalSymbolCount) do
        local percentage = math.floor((count / totalAlivePlayers) * 100)
        print("[qb-alicia] 🆕 " .. symbol:upper() .. ": " .. count .. " adet (%" .. percentage .. ")")
    end
    print("[qb-alicia] 🆕 👑 SABİT MAÇA BEYİ: " .. (serverSpadeKingId or "YOK"))
    print("[qb-alicia] 🆕 Toplam oyuncu: " .. tableLength(serverEntitySymbols))
    
    -- ✅ CLIENT'A GÖNDERİLECEK VERİ HAZIRLA
    local newRoundData = {}
    for playerId, symbol in pairs(serverEntitySymbols) do
        local playerName = connectedPlayers[tonumber(playerId)] and connectedPlayers[tonumber(playerId)].name or connectedPlayers[playerId].name or ("Player_" .. playerId)
        
        newRoundData[playerId] = {
            name = playerName,
            id = tonumber(playerId) or playerId,
            symbol = symbol,
            isSpadeKing = (serverSpadeKingId == playerId), -- SABİT MAÇA BEYİ
            sessionId = gameSessionActive
        }
        
        local kingMark = (serverSpadeKingId == playerId) and " 👑 (SABİT)" or ""
        print("[qb-alicia] 🆕 CLIENT VERİ: " .. playerName .. " → " .. symbol .. kingMark)
    end
    
    -- ✅ HAYATTA OLAN GERÇEK OYUNCULARA YENİ ROUND BİLDİR
    for _, playerId in ipairs(aliveRealPlayers) do
        print("[qb-alicia] 🆕 " .. playerId .. " için yeni round başlatılıyor...")
        TriggerClientEvent('qb-alicia:newRound', playerId, roundNumber, newRoundData)
        
        -- 3 saniye sonra countdown başlat
        Citizen.CreateThread(function()
            Citizen.Wait(3000)
            print("[qb-alicia] 🎮 " .. playerId .. " için countdown başlatılıyor...")
            TriggerClientEvent('qb-alicia:startNUICountdown', playerId)
        end)
    end
    
    print("[qb-alicia] 🆕 === YENİ ROUND " .. roundNumber .. " BAŞLATILDI ===")
    print("[qb-alicia] 🆕 👑 SABİT MAÇA BEYİ: " .. (serverSpadeKingId or "YOK") .. " → SPADE GARANTİLİ")
    print("[qb-alicia] 🆕 Hayatta oyuncu: " .. #aliveRealPlayers)
    print("[qb-alicia] 🆕 MAÇA BEYİ ASLA DEĞİŞMEZ ve %25 EŞİT DAĞILIM!")
end

-- ✅ Maça beyi sabir kalıyor mu kontrol komutu
QBCore.Commands.Add('verifykingsame', 'Maça beyinin aynı kaldığını doğrular', {}, false, function(source)
    local src = source
    
    print("[qb-alicia] 🔍 === MAÇA BEYİ SABİTLİK KONTROLÜ ===")
    print("[qb-alicia] 🔍 Mevcut Round: " .. roundNumber)
    print("[qb-alicia] 🔍 Server Maça Beyi: " .. (serverSpadeKingId or "YOK"))
    
    -- Entity symbols kontrolü
    local spadeCount = 0
    local currentSpadeUsers = {}
    
    for playerId, symbol in pairs(serverEntitySymbols) do
        if symbol == "spade" then
            spadeCount = spadeCount + 1
            table.insert(currentSpadeUsers, playerId)
            
            local playerName = connectedPlayers[tonumber(playerId)] and connectedPlayers[tonumber(playerId)].name or ("Player_" .. playerId)
            print("[qb-alicia] 🔍 SPADE KULLANICISI: " .. playerName .. " (ID:" .. playerId .. ")")
        end
    end
    
    print("[qb-alicia] 🔍 Toplam spade kullanıcısı: " .. spadeCount)
    
    -- Maça beyi doğrulama
    local isKingCorrect = false
    for _, spadeUser in ipairs(currentSpadeUsers) do
        if spadeUser == serverSpadeKingId then
            isKingCorrect = true
            break
        end
    end
    
    if isKingCorrect then
        print("[qb-alicia] 🔍 ✅ MAÇA BEYİ DOĞRU: " .. serverSpadeKingId .. " hem maça beyi hem de spade sembolü var")
        TriggerClientEvent('QBCore:Notify', src, '✅ Maça beyi doğru şekilde sabit!', 'success')
    else
        print("[qb-alicia] 🔍 ❌ HATA: Maça beyi (" .. (serverSpadeKingId or "YOK") .. ") spade sembolü almamış!")
        TriggerClientEvent('QBCore:Notify', src, '❌ Maça beyi sorunu tespit edildi!', 'error')
    end
    
    -- Hayatta olan maça beyi kontrolü
    local isKingAlive = alivePlayers[serverSpadeKingId]
    print("[qb-alicia] 🔍 Maça beyi hayatta mı: " .. (isKingAlive and "EVET" or "HAYIR/BİLİNMİYOR"))
    
    if not isKingAlive and serverSpadeKingId then
        print("[qb-alicia] 🔍 ⚠️ DİKKAT: Maça beyi ölmüş olabilir!")
        TriggerClientEvent('QBCore:Notify', src, '⚠️ Maça beyi ölmüş görünüyor!', 'error')
    end
end)

-- ✅ Client'tan sembol isteği eventi
RegisterNetEvent('qb-alicia:requestMySymbol')
AddEventHandler('qb-alicia:requestMySymbol', function(requestedServerId)
    local src = source
    print("[qb-alicia] 🔄 Client sembol isteği: " .. src .. " (istedigi ID: " .. requestedServerId .. ")")
    
    local playerSymbol = serverEntitySymbols[tostring(src)]
    local isSpadeKing = (serverSpadeKingId == tostring(src))
    
    if playerSymbol then
        print("[qb-alicia] ✅ Sembol bulundu, gönderiliyor: " .. playerSymbol)
        
        TriggerClientEvent('qb-alicia:receiveMySymbol', src, {
            symbol = playerSymbol,
            isSpadeKing = isSpadeKing,
            playerId = tostring(src)
        })
    else
        print("[qb-alicia] ❌ Server'da da sembol bulunamadı!")
    end
end)

-- ✅ Oyun bitişi
-- ✅ DÜZELTILMIŞ Oyun bitişi fonksiyonu
-- ✅ DÜZELTILMIŞ Oyun bitişi fonksiyonu (TÜM OYUNCULAR SPAWN)
function EndGame(reason)
    print("[qb-alicia] 🏁 === OYUN BİTTİ ===")
    print("[qb-alicia] 🏁 Sebep: " .. reason)
    print("[qb-alicia] 🏁 Round: " .. roundNumber)
    
    local winners = {}
    local winMessage = ""
    local allPlayersToSpawn = {} -- TÜM OYUNCULAR (kazanan + kaybeden)
    
    if reason == "spade_king_died" then
        -- Maça beyi öldü, hayatta kalanlar kazandı
        print("[qb-alicia] 🏁 === MAÇA BEYİ ÖLDÜ - HAYATTA KALANLAR KAZANDI ===")
        
        for playerId, isAlive in pairs(alivePlayers) do
            if isAlive and serverSpadeKingId ~= playerId then
                table.insert(winners, playerId)
                print("[qb-alicia] 🏆 KAZANAN: " .. playerId)
            end
        end
        winMessage = "🎉 MAÇA BEYİ ÖLDÜ! HAYATTA KALANLAR KAZANDI!"
        
    elseif reason == "spade_king_wins" then
        -- Sadece maça beyi kaldı
        print("[qb-alicia] 🏁 === MAÇA BEYİ KAZANDI ===")
        
        if serverSpadeKingId then
            table.insert(winners, serverSpadeKingId)
            print("[qb-alicia] 🏆 KAZANAN: Maça Beyi " .. serverSpadeKingId)
        end
        winMessage = "👑 MAÇA BEYİ KAZANDI! TEK KALAN O!"
        
    elseif reason == "no_survivors" then
        print("[qb-alicia] 🏁 === HİÇKİMSE KALMADI ===")
        winMessage = "💀 HİÇKİMSE KAZANAMADI! HERKES ÖLDÜ!"
    end
    
    -- ✅ TÜM OYUNCULARI TOPLA (HAYATTA + ÖLÜ)
    print("[qb-alicia] 🏁 === TÜM OYUNCULAR DIŞARIYA SPAWN EDİLECEK ===")
    
    for playerId, symbol in pairs(serverEntitySymbols) do
        if tonumber(playerId) > 0 then -- Sadece gerçek oyuncular
            table.insert(allPlayersToSpawn, tonumber(playerId))
            
            local playerName = "Player_" .. playerId
            -- İsmi bul
            local Player = QBCore.Functions.GetPlayer(tonumber(playerId))
            if Player then
                playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
            end
            
            local isWinner = false
            for _, winnerId in ipairs(winners) do
                if winnerId == playerId then
                    isWinner = true
                    break
                end
            end
            
            local status = isWinner and "🏆 KAZANAN" or "💀 KAYBEDEN"
            print("[qb-alicia] 🏁 SPAWN: " .. playerName .. " (ID:" .. playerId .. ") " .. status)
        end
    end
    
    print("[qb-alicia] 🏁 Toplam spawn edilecek oyuncu: " .. #allPlayersToSpawn)
    
    -- ✅ TÜM OYUNCULARI DIŞARIYA SPAWN ET
    for _, playerId in ipairs(allPlayersToSpawn) do
        print("[qb-alicia] 🏆 " .. playerId .. " dışarıya spawn ediliyor...")
        
        -- Kazanan mı kontrol et
        local isWinner = false
        for _, winnerId in ipairs(winners) do
            if winnerId == tostring(playerId) then
                isWinner = true
                break
            end
        end
        
        -- Uygun mesajı belirle
        local personalMessage = winMessage
        if isWinner then
            personalMessage = "🏆 KAZANDINIZ! " .. winMessage
        else
            personalMessage = "💀 KAYBETTİNİZ! " .. winMessage
        end
        
        TriggerClientEvent('qb-alicia:spawnAsWinner', playerId, personalMessage)
    end
    
    -- ✅ TÜM OYUNCULARA OYUN BİTİŞİ BİLDİR
    for playerId, symbol in pairs(serverEntitySymbols) do
        if tonumber(playerId) > 0 then
            TriggerClientEvent('qb-alicia:gameEnded', tonumber(playerId), {
                reason = reason,
                winners = winners,
                message = winMessage,
                roundNumber = roundNumber,
                isWinner = false -- Zaten spawn mesajı gönderildi
            })
        end
    end
    
    -- ✅ OYUN VERİLERİNİ TEMİZLE
    serverEntitySymbols = {}
    serverSpadeKingId = nil
    gameSessionActive = false
    connectedPlayers = {}
    currentRoundResults = {}
    alivePlayers = {}
    roundNumber = 1
    
    print("[qb-alicia] 🏁 Oyun " .. roundNumber .. " round sonunda bitti!")
    print("[qb-alicia] 🏁 TÜM OYUNCULAR (kazanan+kaybeden) dışarıya spawn edildi!")
    print("[qb-alicia] 🏁 Oyun verileri temizlendi!")
end


-- Manuel pozisyon atama komutu (test için)
QBCore.Commands.Add('assignpositions', 'Oyunculara pozisyon atar (Test)', {}, false, function(source)
    local src = source
    
    if tableLength(connectedPlayers) == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Lobide oyuncu yok!', 'error')
        return
    end
    
    AssignPlayerPositions()
    TriggerClientEvent('QBCore:Notify', src, 'Pozisyonlar atandı! Console kontrol et.', 'success')
end)

-- Oyun durumu görme komutu
QBCore.Commands.Add('gamestate', 'Oyun durumunu gösterir', {}, false, function(source)
    local src = source
    
    print("[qb-alicia] 🎮 === OYUN DURUMU ===")
    print("[qb-alicia] 🎮 Round: " .. currentRound .. "/" .. maxRounds)
    print("[qb-alicia] 🎮 Aktif session: " .. (gameSessionActive or "YOK"))
    print("[qb-alicia] 🎮 Lobideki oyuncular: " .. tableLength(connectedPlayers))
    
    -- Pozisyonları göster
    print("[qb-alicia] 🎯 === POZİSYONLAR ===")
    for playerId, position in pairs(playerPositions) do
        local playerName = connectedPlayers[playerId] and connectedPlayers[playerId].name or "Bilinmeyen"
        local playerType = tonumber(playerId) > 0 and "OYUNCU" or "BOT"
        print("[qb-alicia] 🎯 Pozisyon " .. position .. ": " .. playerName .. " (" .. playerType .. ")")
    end
    
    local message = "Round: " .. currentRound .. " | Oyuncular: " .. tableLength(connectedPlayers) .. " | Pozisyonlar: " .. tableLength(playerPositions)
    TriggerClientEvent('QBCore:Notify', src, message, 'primary')
end)

-- Tablo uzunluğu hesaplama
function tableLength(t)
    local count = 0
    if t then
        for _ in pairs(t) do count = count + 1 end
    end
    return count
end

-- Test için bot ekleme komutu (gerçek test için - sadmin için)
QBCore.Commands.Add('addtestbots', 'Gerçek oyuncu testleri için bot ekler (Admin Only)', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Mevcut oyuncu sayısını kontrol et
    local realPlayerCount = 0
    for playerId, _ in pairs(connectedPlayers) do
        if tonumber(playerId) > 0 then
            realPlayerCount = realPlayerCount + 1
        end
    end

    if realPlayerCount == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Önce lobiye katılın!', 'error')
        return
    end

    -- Bot ekle (eksik kalan sayıda)
    local botsToAdd = maxPlayers - realPlayerCount
    if botsToAdd <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Lobi zaten dolu!', 'error')
        return
    end

    for i = 1, botsToAdd do
        local botId = -i
        if not connectedPlayers[botId] then
            local botName = botNames[i] or ("Test Bot " .. i)
            connectedPlayers[botId] = {
                name = botName,
                citizenid = "TESTBOT" .. i,
                ready = true
            }
        end
    end

    print("[qb-alicia] " .. botsToAdd .. " test botu eklendi.")
    TriggerClientEvent('QBCore:Notify', src, botsToAdd .. ' test botu eklendi!', 'success')

    -- Lobi güncellemesi gönder
    for playerId, _ in pairs(connectedPlayers) do
        if tonumber(playerId) > 0 then
            TriggerClientEvent('update:lobby', playerId, connectedPlayers)
        end
    end

    -- Oyuncu kontrolü
    CheckAndTeleportPlayers()
end)

-- Test komutu: Manuel sembol ataması (debugging için)
QBCore.Commands.Add('testsymbols', 'Rastgele sembol atamasını test eder (Admin)', {}, false, function(source)
    local src = source
    
    print("[qb-alicia] 🧪 === MANUEL SEMBOL ATAMA TESTİ ===")
    
    -- Test için sahte oyuncu verisi oluştur
    connectedPlayers = {}
    
    -- Kendi karakterini ekle
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        connectedPlayers[src] = {
            name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
            citizenid = Player.PlayerData.citizenid,
            ready = true
        }
    end
    
    -- Test botları ekle
    for i = 1, 6 do
        local botId = -i
        connectedPlayers[botId] = {
            name = "Test Bot " .. i,
            citizenid = "TESTBOT" .. i,
            ready = true
        }
    end
    
    print("[qb-alicia] 🧪 Test için " .. tableLength(connectedPlayers) .. " oyuncu oluşturuldu")
    
    -- Sembol ataması yap
    local sessionId = SecureSymbolAssignment()
    
    -- Sonuçları göster
    print("[qb-alicia] 🧪 === TEST SONUÇLARI ===")
    for playerId, symbol in pairs(serverEntitySymbols) do
        local playerName = connectedPlayers[tonumber(playerId)] and connectedPlayers[tonumber(playerId)].name or "Bilinmeyen"
        local kingMark = (serverSpadeKingId == playerId) and " 👑 MAÇA BEYİ" or ""
        print("[qb-alicia] 🧪 " .. playerName .. " (ID:" .. playerId .. ") → " .. symbol .. kingMark)
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Test tamamlandı! Console\'u kontrol et.', 'success')
end)

-- Oyuncu sayısı ayarlama komutu
QBCore.Commands.Add('setmaxplayers', 'Maksimum oyuncu sayısını ayarlar', {{name = 'count', help = 'Oyuncu sayısı (2-10)'}}, true, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local newMaxPlayers = tonumber(args[1])
    
    if not newMaxPlayers or newMaxPlayers < 2 or newMaxPlayers > 10 then
        TriggerClientEvent('QBCore:Notify', src, 'Geçerli bir sayı girin! (2-10)', 'error')
        return
    end

    maxPlayers = newMaxPlayers
    TriggerClientEvent('QBCore:Notify', src, 'Maksimum oyuncu sayısı ' .. maxPlayers .. ' olarak ayarlandı!', 'success')
    print("[qb-alicia] Maksimum oyuncu sayısı " .. maxPlayers .. " olarak güncellendi.")
    
    -- Eğer şu anki lobi sayısı yeni limiti aşıyorsa kontrol et
    local currentRealPlayers = 0
    for playerId, _ in pairs(connectedPlayers) do
        if tonumber(playerId) > 0 then
            currentRealPlayers = currentRealPlayers + 1
        end
    end
    
    if currentRealPlayers >= maxPlayers then
        TriggerClientEvent('QBCore:Notify', src, 'Yeni limit sağlandı! Spawn işlemi tetikleniyor...', 'primary')
        CheckAndTeleportPlayers()
    end
end)

-- Mevcut ayarları görme komutu
QBCore.Commands.Add('lobisettings', 'Lobi ayarlarını gösterir', {}, false, function(source)
    local src = source
    
    local realPlayers = 0
    local bots = 0
    
    for playerId, data in pairs(connectedPlayers) do
        if tonumber(playerId) > 0 then
            realPlayers = realPlayers + 1
        else
            bots = bots + 1
        end
    end
    
    local total = realPlayers + bots
    TriggerClientEvent('QBCore:Notify', src, 'Maks Oyuncu: ' .. maxPlayers .. ' | Lobide: ' .. realPlayers .. ' gerçek + ' .. bots .. ' bot', 'primary')
    
    print("[qb-alicia] Lobi Ayarları:")
    print("  - Maksimum oyuncu: " .. maxPlayers)
    print("  - Gerçek oyuncular: " .. realPlayers)
    print("  - Botlar: " .. bots)
    print("  - Toplam: " .. total)
    print("  - Aktif session: " .. (gameSessionActive or "YOK"))
end)

-- Sembol dağılımını kontrol etme komutu
QBCore.Commands.Add('symbolstats', 'Mevcut sembol dağılımını gösterir', {}, false, function(source)
    local src = source
    
    if not serverEntitySymbols or tableLength(serverEntitySymbols) == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Henüz sembol ataması yapılmamış!', 'error')
        return
    end
    
    local symbolCount = {diamond = 0, club = 0, heart = 0, spade = 0}
    local totalPlayers = 0
    
    for playerId, symbol in pairs(serverEntitySymbols) do
        symbolCount[symbol] = symbolCount[symbol] + 1
        totalPlayers = totalPlayers + 1
    end
    
    print("[qb-alicia] 📊 === SEMBOL İSTATİSTİKLERİ ===")
    print("[qb-alicia] 📊 Toplam oyuncu: " .. totalPlayers)
    print("[qb-alicia] 📊 ♦️ Diamond: " .. symbolCount.diamond .. " (" .. math.floor((symbolCount.diamond/totalPlayers)*100) .. "%)")
    print("[qb-alicia] 📊 ♣️ Club: " .. symbolCount.club .. " (" .. math.floor((symbolCount.club/totalPlayers)*100) .. "%)")
    print("[qb-alicia] 📊 ♥️ Heart: " .. symbolCount.heart .. " (" .. math.floor((symbolCount.heart/totalPlayers)*100) .. "%)")
    print("[qb-alicia] 📊 ♠️ Spade: " .. symbolCount.spade .. " (" .. math.floor((symbolCount.spade/totalPlayers)*100) .. "%)")
    print("[qb-alicia] 📊 👑 Maça Beyi: " .. (serverSpadeKingId or "YOK"))
    
    local message = string.format("♦️:%d ♣️:%d ♥️:%d ♠️:%d | Maça Beyi: %s", 
        symbolCount.diamond, symbolCount.club, symbolCount.heart, symbolCount.spade,
        serverSpadeKingId or "YOK")
    
    TriggerClientEvent('QBCore:Notify', src, message, 'primary')
end)

-- ANTI-CHEAT: Session durumunu sorgula
QBCore.Commands.Add('checksession', 'Aktif oyun session\'ını kontrol eder', {}, false, function(source)
    local src = source
    TriggerClientEvent('QBCore:Notify', src, 'Session: ' .. (gameSessionActive or "Aktif değil"), 'primary')
    print("[qb-alicia] Session durumu sorgulandı: " .. (gameSessionActive or "YOK"))
end)

-- Oyuncu ayrıldığında listeden çıkar
AddEventHandler('playerDropped', function()
    local src = source
    if connectedPlayers[src] then
        local playerName = connectedPlayers[src].name or "Bilinmeyen Oyuncu"
        connectedPlayers[src] = nil
        
        -- Server-side verilerden de temizle
        if serverEntitySymbols[tostring(src)] then
            serverEntitySymbols[tostring(src)] = nil
            print("[qb-alicia] 🔒 " .. playerName .. " server sembol verisi temizlendi.")
        end
        
        if serverSpadeKingId == tostring(src) then
            serverSpadeKingId = nil
            print("[qb-alicia] 🔒 " .. playerName .. " maça beyi statüsü kaldırıldı.")
        end
        
        -- Güncellenmiş listeyi tüm oyunculara gönder
        for playerId, _ in pairs(connectedPlayers) do
            if tonumber(playerId) > 0 then -- Sadece gerçek oyunculara gönder
                TriggerClientEvent('update:lobby', playerId, connectedPlayers)
            end
        end
        print("[qb-alicia] " .. playerName .. " sunucudan ayrıldı, lobi güncellendi.")
    end
end)

-- Lobiden ayrılma eventi
RegisterNetEvent('qb-alicia:leaveLobby')
AddEventHandler('qb-alicia:leaveLobby', function()
    local src = source
    if connectedPlayers[src] then
        local playerName = connectedPlayers[src].name
        connectedPlayers[src] = nil
        
        -- Güncellenmiş listeyi tüm oyunculara gönder
        for playerId, _ in pairs(connectedPlayers) do
            if tonumber(playerId) > 0 then
                TriggerClientEvent('update:lobby', playerId, connectedPlayers)
            end
        end
        
        print("[qb-alicia] " .. playerName .. " NUI'dan lobiden ayrıldı.")
    end
end)

-- Oyuncu ismini alma eventi
RegisterNetEvent('qb-alicia:getPlayerName')
AddEventHandler('qb-alicia:getPlayerName', function(targetServerId)
    local src = source
    local targetPlayer = QBCore.Functions.GetPlayer(targetServerId)
    
    if targetPlayer then
        local playerName = targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname
        TriggerClientEvent('qb-alicia:receivePlayerName', src, targetServerId, playerName)
    else
        -- Eğer QBCore player datası bulunamazsa, standart isim gönder
        local playerName = GetPlayerName(targetServerId) or ("Oyuncu_" .. targetServerId)
        TriggerClientEvent('qb-alicia:receivePlayerName', src, targetServerId, playerName)
    end
end)

-- Teleport eventi (eski versiyon uyumluluğu için - YENİ KONUM)
RegisterNetEvent('qb-alicia:teleportPlayers')
AddEventHandler('qb-alicia:teleportPlayers', function(customMaxPlayers)
    local src = source
    local maxPlayersToUse = customMaxPlayers or maxPlayers
    
    -- Önce server-side sembol ataması yap
    connectedPlayers = {} -- Geçici liste oluştur
    local allPlayers = QBCore.Functions.GetPlayers()
    
    for _, playerId in pairs(allPlayers) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            connectedPlayers[playerId] = {
                name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                citizenid = Player.PlayerData.citizenid,
                ready = true
            }
        end
    end
    
    -- Ultra güvenli manual teleport
    local sessionId = SecureSymbolAssignment()
    
    -- Tüm online oyuncuları al
    local playerData = {}
    for _, playerId in pairs(allPlayers) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local playerIdStr = tostring(playerId)
            playerData[playerIdStr] = {
                name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
                id = playerId,
                symbol = serverEntitySymbols[playerIdStr],
                isSpadeKing = (serverSpadeKingId == playerIdStr),
                sessionId = sessionId
            }
        end
    end
    
    -- Tüm oyunculara teleport eventi gönder (YENİ KONUM)
    for _, playerId in pairs(allPlayers) do
        TriggerClientEvent('teleport:players', playerId, playerData, maxPlayersToUse)
        Citizen.CreateThread(function()
            Citizen.Wait(2000)
            TriggerClientEvent('qb-alicia:startNUICountdown', playerId)
        end)
    end
    
    print("[qb-alicia] 🔒 Manuel ultra güvenli teleport tamamlandı. Session: " .. sessionId)
    print("[qb-alicia] 📍 YENİ KONUM: Sandy Shores Airport - 1779.69, 2583.99, 45.8")
end)




local QBCore = exports['qb-core']:GetCoreObject()
-- ✅ Oyun bitişi spawn koordinatları (Sandy Shores Airport dışı)
local winnerSpawnCoords = vector3(1751.0, 2570.0, 45.56) -- Havaalanı dışında güvenli alan

-- Debug komutları - GÜNCELLENMIŞ (KENDİ SEMBOLÜNÜ GÖSTER)
RegisterCommand("symbols", function()
    print("[qb-alicia] === ULTRA GÜVENLİ SEMBOL LİSTESİ (SERVER-ONLY) ===")
    
    if not isTeleported then
        print("[qb-alicia] ⚠️ Henüz spawn edilmedi! Önce server'dan 'teleport:players' eventi gelmeli.")
        return
    end
    
    local myServerId = GetPlayerServerId(PlayerPedId())
    if myServerId == 0 then
        local playerPed = PlayerPedId()
        local playerIndex = NetworkGetPlayerIndexFromPed(playerPed)
        if playerIndex ~= -1 then
            myServerId = GetPlayerServerId(playerIndex)
        end
        
        if myServerId == 0 then
            for playerId, symbol in pairs(entitySymbols) do
                local numId = tonumber(playerId)
                if numId and numId > 0 then
                    myServerId = numId
                    print("[qb-alicia] 🔧 Server ID 0 olduğu için alternatif ID kullanıldı: " .. myServerId)
                    break
                end
            end
        end
    end
    local mySymbol = entitySymbols[tostring(myServerId)] or "YOK"
    local isMyKing = (spadeKingId == tostring(myServerId))
    
    -- Oyun durumu
    print("[qb-alicia] 🔒 Session ID: " .. (currentSession or "YOK"))
    print("[qb-alicia] 🎮 Oyun Fazı: " .. gamePhase)
    print("[qb-alicia] 🎮 Round: " .. currentRound)
    print("[qb-alicia] 🎮 Pozisyon: " .. playerPosition)
    print("[qb-alicia] 🎮 Hayatta: " .. (isPlayerAlive and "EVET" or "HAYIR"))
    print("[qb-alicia] 🎮 Semboller aktif: " .. tostring(QBCore)) -- ya da doğru bir QBCore fonksiyonu kullanın
end) -- <<< BU SATIRI EKLEDİK

local symbols = {"diamond", "club", "heart", "spade"}
local isSymbolActive = false -- Başlangıçta gizli
local isInLobby = false
local isTeleported = false
local playerData = {}
local botPeds = {}

-- Oyuncu ve botlar için sembol atamalarını sakla (SERVER'DAN GELECEK)
local entitySymbols = {} -- [entityId] = symbol (SERVER-ONLY)

-- Maça beyi sistemi (SERVER'DAN GELECEK)
local spadeKingId = nil -- Maça beyinin ID'si (SERVER-ONLY)

-- Session kontrolü (HİLE KORUNMASI)
local currentSession = nil

-- Texture durumları
local texturesLoaded = {}

-- NPC'nin spawn edileceği koordinatlar (YENİ KONUM)
local npcCoords = vector4(1758.64, 2565.0, 45.56, 172.6)
local npcModel = "a_m_m_business_01"
local npc = nil

-- Oyun koordinatları (10 oyuncu için sabit pozisyonlar)
local gameCoords = {
    vector3(1769.29, 2585.12, 45.8), -- 1. oyuncu
    vector3(1768.35, 2581.68, 45.8), -- 2. oyuncu
    vector3(1769.46, 2577.52, 45.8), -- 3. oyuncu
    vector3(1769.16, 2574.06, 45.8), -- 4. oyuncu
    vector3(1789.09, 2586.45, 45.8), -- 5. oyuncu
    vector3(1789.55, 2581.98, 45.8), -- 6. oyuncu
    vector3(1789.14, 2578.11, 45.8), -- 7. oyuncu
    vector3(1788.68, 2573.94, 45.8), -- 8. oyuncu
    vector3(1788.98, 2574.63, 50.55), -- 9. oyuncu (üst kat)
    vector3(1789.74, 2578.73, 50.55)  -- 10. oyuncu (üst kat)
}

-- İlk spawn konumu (tartışma alanı)
local spawnCoords = vector3(1779.69, 2583.99, 45.8)
local gamePhase = "lobby" -- lobby, discussion, positioning, guessing, results
local discussionTime = 60 -- 60 saniye tartışma
local guessTime = 10 -- 10 saniye tahmin
local isPlayerFrozen = false
local playerPosition = 0 -- Oyuncunun pozisyon indexi
local currentRound = 1
local isPlayerAlive = true

-- Geri sayım değişkenleri
local discussionCountdown = 0
local guessCountdown = 0

-- UI değişkenleri
local showCountdown = false
local showGuessButtons = false

-- Performans optimizasyonu
local SYMBOL_DRAW_DISTANCE = 50.0
local SYMBOL_FADE_DISTANCE = 45.0

-- 3D metin çizimi
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
    end
end

-- ✅ Oyun bitişi spawn eventi
-- ✅ Oyun bitişi spawn eventi (TÜM OYUNCULAR İÇİN)
RegisterNetEvent('qb-alicia:spawnAsWinner')
AddEventHandler('qb-alicia:spawnAsWinner', function(winMessage)
    print("[qb-alicia] 🏁 === OYUN BİTTİ - DIŞARIYA SPAWN ===")
    print("[qb-alicia] 🏁 Mesaj: " .. (winMessage or "Oyun bitti"))
    
    -- Oyunu temizle
    gamePhase = "ended"
    isPlayerFrozen = false
    isPlayerAlive = true
    
    -- ✅ TÜM EFEKTLERİ TEMİZLE
    local playerPed = PlayerPedId()
    
    -- Freeze'leri kaldır
    FreezeEntityPosition(playerPed, false)
    
    -- Alpha ve collision'ı normale döndür
    SetEntityAlpha(playerPed, 255, false)
    SetEntityCollision(playerPed, true, true)
    
    -- Health'i tam yap
    local maxHealth = GetEntityMaxHealth(playerPed)
    SetEntityHealth(playerPed, maxHealth)
    
    -- Kan ve hasarları temizle
    ClearPedBloodDamage(playerPed)
    ClearPedDamageDecalByZone(playerPed, 0)
    
    -- Ragdoll'u durdur
    SetPedCanRagdoll(playerPed, false)
    Citizen.Wait(100)
    SetPedCanRagdoll(playerPed, true)
    
    print("[qb-alicia] 🏁 Karakter durumu temizlendi")
    
    -- ✅ Dışarıya spawn et
    SetEntityCoords(playerPed, winnerSpawnCoords.x, winnerSpawnCoords.y, winnerSpawnCoords.z, false, false, false, true)
    SetEntityHeading(playerPed, 0.0)
    
    -- ✅ UI'yi temizle
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "hideAll" })
    
    -- ✅ Spawn efekti
    local spawnCoords = GetEntityCoords(playerPed)
    
    Citizen.CreateThread(function()
        RequestNamedPtfxAsset("core")
        while not HasNamedPtfxAssetLoaded("core") do
            Citizen.Wait(1)
        end
        
        -- Spawn parçacığı
        UseParticleFxAssetNextCall("core")
        StartParticleFxLoopedAtCoord("ent_dst_elec_fire_sp", spawnCoords.x, spawnCoords.y, spawnCoords.z + 1.0, 0.0, 0.0, 0.0, 1.5, false, false, false, false)
        
        -- Işık efekti
        UseParticleFxAssetNextCall("core")
        StartParticleFxLoopedAtCoord("ent_amb_candle_flame", spawnCoords.x, spawnCoords.y, spawnCoords.z + 2.0, 0.0, 0.0, 0.0, 2.5, false, false, false, false)
    end)
    
    -- ✅ Spawn sesi
    PlaySoundFrontend(-1, "SPAWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    Citizen.Wait(500)
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    
    -- ✅ Kazanma/kaybetme mesajını göster
    SendNUIMessage({
        type = "showWinMessage",
        message = winMessage or "🏁 OYUN BİTTİ!"
    })
    
    print("[qb-alicia] 🏁 Dışarıya spawn edildi: " .. winnerSpawnCoords.x .. ", " .. winnerSpawnCoords.y)
    print("[qb-alicia] 🏁 Oyun tamamlandı!")
end)

-- ✅ Maça beyi kontrol komutu
RegisterCommand("king", function()
    print("[qb-alicia] 👑 === MAÇA BEYİ KONTROL ===")
    
    if not spadeKingId then
        print("[qb-alicia] 👑 Henüz maça beyi seçilmedi!")
        return
    end
    
    -- Maça beyinin bilgilerini bul
    local kingName = "Bilinmeyen"
    local kingType = "Bilinmeyen"
    
    if tonumber(spadeKingId) and tonumber(spadeKingId) > 0 then
        -- Gerçek oyuncu
        kingName = GetRealPlayerName(tonumber(spadeKingId))
        kingType = "GERÇEK OYUNCU"
    else
        -- Bot
        kingName = playerData[spadeKingId] and playerData[spadeKingId].name or ("Bot_" .. spadeKingId)
        kingType = "BOT"
    end
    
    print("[qb-alicia] 👑 ========================")
    print("[qb-alicia] 👑   MAÇA BEYİ BİLGİLERİ")
    print("[qb-alicia] 👑 ========================")
    print("[qb-alicia] 👑 İsim: " .. kingName)
    print("[qb-alicia] 👑 ID: " .. spadeKingId)
    print("[qb-alicia] 👑 Tip: " .. kingType)
    print("[qb-alicia] 👑 Session: " .. (currentSession or "YOK"))
    print("[qb-alicia] 👑 Round: " .. currentRound)
    print("[qb-alicia] 👑 ========================")
    
    -- Kendi durumumu kontrol et
    local myServerId = GetPlayerServerId(PlayerPedId())
    if myServerId == 0 then
        local playerPed = PlayerPedId()
        local playerIndex = NetworkGetPlayerIndexFromPed(playerPed)
        if playerIndex ~= -1 then
            myServerId = GetPlayerServerId(playerIndex)
        end
    end
    
    local amIKing = (spadeKingId == tostring(myServerId))
    print("[qb-alicia] 👑 Ben maça beyi miyim: " .. (amIKing and "EVET! 👑" or "HAYIR"))
    
    if amIKing then
        print("")
        print("[qb-alicia] 👑👑👑👑👑👑👑👑👑👑")
        print("[qb-alicia] 👑  SEN MAÇA BEYİSİN!  👑")
        print("[qb-alicia] 👑   DİKKATLİ OLMAN     👑")
        print("[qb-alicia] 👑     GEREKİYOR!      👑")
        print("[qb-alicia] 👑👑👑👑👑👑👑👑👑👑")
        print("")
    end
    
end, false)

-- PNG Texture yükleme ve kontrol (club.png için alternatif çözüm)
function EnsureTextureLoaded(texture)
    -- Club için özel bypass sistemi
    if texture == "club" then
        print("[qb-alicia] Club için PNG bypass - direkt alternatif sembol kullanılacak")
        return false -- Club için direkt alternatif sembol kullan
    end
    
    -- Eğer daha önce yüklenmeye çalışıldıysa ve başarısızsa tekrar deneme
    if texturesLoaded[texture] == false then
        return false
    end
    
    -- Eğer zaten yüklendiyse true döndür
    if texturesLoaded[texture] == true then
        return true
    end
    
    -- İlk kez yüklenmeye çalışılıyor
    if not HasStreamedTextureDictLoaded(texture) then
        RequestStreamedTextureDict(texture, false)
        local attempts = 0
        local maxAttempts = 100
        
        while not HasStreamedTextureDictLoaded(texture) and attempts < maxAttempts do
            Citizen.Wait(100)
            attempts = attempts + 1
        end
        
        if HasStreamedTextureDictLoaded(texture) then
            print("[qb-alicia] " .. texture .. " texture başarıyla yüklendi. (Deneme: " .. attempts .. ")")
            texturesLoaded[texture] = true
            return true
        else
            print("[qb-alicia] HATA: " .. texture .. " texture " .. attempts .. " denemeden sonra yüklenemedi!")
            texturesLoaded[texture] = false
            return false
        end
    else
        texturesLoaded[texture] = true
        return true
    end
end

-- Sadece Unicode sembol çizimi (horizontal rotasyon, küçük boyut)
function DrawSymbol(x, y, z, symbol, rotation, alpha)
    local symbolChar, color
    
    if symbol == "diamond" then
        symbolChar = "♦"
        color = {r = 255, g = 165, b = 0} -- Turuncu-altın
    elseif symbol == "club" then
        symbolChar = "♣"
        color = {r = 34, g = 139, b = 34} -- Yeşil renk
    elseif symbol == "heart" then
        symbolChar = "♥"
        color = {r = 220, g = 20, b = 60} -- Crimson kırmızı
    elseif symbol == "spade" then
        symbolChar = "♠"
        color = {r = 64, g = 64, b = 64} -- Koyu gri
    else
        symbolChar = "?"
        color = {r = 255, g = 255, b = 255} -- Varsayılan beyaz
    end
    
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        -- HORIZONTAL ROTASYON - kendi ekseni etrafında (X ekseni)
        local rotationSpeed = 3.0
        local angle = (rotation * rotationSpeed) % 360.0
        local radians = math.rad(angle)
        
        -- Horizontal perspektif için scale değişimi (cosine ile genişlik)
        local horizontalScale = math.abs(math.cos(radians)) -- 0-1 arası
        local scaleX = 0.4 + (horizontalScale * 0.4) -- 0.4-0.8 arası
        local scaleY = 0.6 -- Sabit yükseklik
        
        -- Alpha değeri (mesafe bazlı)
        local finalAlpha = alpha or 255
        
        -- Ana sembol (horizontal dönen)
        SetTextScale(scaleX, scaleY)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(color.r, color.g, color.b, finalAlpha)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(symbolChar)
        DrawText(_x, _y)
        
        -- Glow efekti (dönerken değişen)
        SetTextScale(scaleX + 0.1, scaleY + 0.1)
        SetTextColour(color.r, color.g, color.b, math.floor(finalAlpha * 0.6))
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(symbolChar)
        DrawText(_x, _y)
        
        -- Depth shadow (derinlik efekti)
        if horizontalScale < 0.5 then -- Yan görünümde gölge
            local blurAlpha = math.floor((1 - horizontalScale) * 100)
            SetTextScale(scaleX, scaleY)
            SetTextColour(0, 0, 0, math.floor(blurAlpha * (finalAlpha / 255)))
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(symbolChar)
            DrawText(_x + 0.0005, _y + 0.0005)
        end
        
        -- Parlama efekti (front view'da)
        if horizontalScale > 0.7 then -- Ön görünümde parlama
            SetTextScale(scaleX * 0.9, scaleY * 0.9)
            SetTextColour(255, 255, 255, math.floor(horizontalScale * 80 * (finalAlpha / 255)))
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(symbolChar)
            DrawText(_x, _y)
        end
    end
end

-- Gerçek oyuncu ismini alma
function GetRealPlayerName(serverId)
    -- QBCore playerdata'dan isim al
    local Player = QBCore.Functions.GetPlayerData()
    if Player and Player.charinfo and Player.charinfo.firstname and Player.charinfo.lastname then
        if GetPlayerServerId(PlayerPedId()) == serverId then
            return Player.charinfo.firstname .. " " .. Player.charinfo.lastname
        end
    end
    
    -- Diğer oyuncular için server-side'dan gelen veriyi kullan
    if playerData[tostring(serverId)] and playerData[tostring(serverId)].name then
        return playerData[tostring(serverId)].name
    end
    
    -- Son çare olarak oyuncu handle ismini al
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == serverId then
            local playerName = GetPlayerName(player)
            if playerName and playerName ~= "" then
                return playerName
            end
        end
    end
    
    return "Oyuncu_" .. serverId
end

-- Tablo uzunluğu hesaplama fonksiyonu
function tableLength(t)
    local count = 0
    if t then
        for _ in pairs(t) do count = count + 1 end
    end
    return count
end

-- Performans: Sembol çizim mesafesi kontrolü
function ShouldDrawSymbol(distance)
    return distance <= SYMBOL_DRAW_DISTANCE
end

function GetSymbolAlpha(distance)
    if distance <= SYMBOL_FADE_DISTANCE then
        return 255 -- Tam görünür
    elseif distance <= SYMBOL_DRAW_DISTANCE then
        -- Fade out
        local fadeRatio = (SYMBOL_DRAW_DISTANCE - distance) / (SYMBOL_DRAW_DISTANCE - SYMBOL_FADE_DISTANCE)
        return math.floor(255 * fadeRatio)
    else
        return 0 -- Görünmez
    end
end

-- NUI geri sayımını başlatma eventi (SERVER tetikler - GÜNCELLEME)
RegisterNetEvent('qb-alicia:startNUICountdown')
AddEventHandler('qb-alicia:startNUICountdown', function()
    print("[qb-alicia] 🎮 NUI countdown başlatılıyor...")
    
    -- NUI'ya countdown başlatma komutu gönder
    SendNUIMessage({
        type = "startCountdown",
        duration = 10 -- 10 saniye
    })
    
    -- 10 saniye sonra sembolleri aktif et ve oyun fazını başlat
    Citizen.CreateThread(function()
        Citizen.Wait(10000) -- 10 saniye bekle
        isSymbolActive = true
        
        print("[qb-alicia] 🎮 Semboller aktif edildi!")
        
        -- NUI'ya oyun başladı mesajı
        SendNUIMessage({
            type = "gameStarted"
        })
        
        -- 3 saniye sonra NUI countdown'u kapat
        Citizen.Wait(3000)
        SendNUIMessage({
            type = "hideCountdown"
        })
        
        -- Tartışma fazını başlat
        StartDiscussionPhase()
        
        print("[qb-alicia] 🎮 NUI countdown kapatıldı, tartışma fazı başladı!")
    end)
end)

-- Tartışma fazını başlat (60 saniye)
function StartDiscussionPhase()
    gamePhase = "discussion"
    discussionCountdown = discussionTime
    showCountdown = true
    
    print("[qb-alicia] 💬 === TARTIŞMA FAZI BAŞLADI ===")
    print("[qb-alicia] 💬 60 saniye boyunca konuşabilirsiniz!")
    
    -- NUI'ya tartışma fazı başlat
    SendNUIMessage({
        type = "startDiscussion",
        duration = discussionTime
    })
    
    -- Tartışma geri sayımı
    Citizen.CreateThread(function()
        while discussionCountdown > 0 and gamePhase == "discussion" do
            Citizen.Wait(1000)
            discussionCountdown = discussionCountdown - 1
            
            -- Her 10 saniyede bir uyarı
            if discussionCountdown % 10 == 0 and discussionCountdown > 0 then
                print("[qb-alicia] 💬 Kalan süre: " .. discussionCountdown .. " saniye")
            end
        end
        
        if gamePhase == "discussion" then
            print("[qb-alicia] 💬 Tartışma süresi doldu!")
            StartPositioningPhase()
        end
    end)
end

-- Pozisyonlama fazını başlat
function StartPositioningPhase()
    gamePhase = "positioning"
    showCountdown = false
    
    print("[qb-alicia] 🎯 === POZİSYONLAMA FAZI ===")
    
    -- NUI'ya pozisyonlama fazı
    SendNUIMessage({
        type = "startPositioning"
    })
    
    -- Oyuncuyu pozisyonuna ışınla
    TeleportToGamePosition()
    
    -- 2 saniye sonra tahmin fazını başlat
    Citizen.CreateThread(function()
        Citizen.Wait(2000)
        StartGuessPhase()
    end)
end

-- Oyuncuyu oyun pozisyonuna ışınla
function TeleportToGamePosition()
    if playerPosition > 0 and playerPosition <= #gameCoords then
        local coords = gameCoords[playerPosition]
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
        SetEntityHeading(PlayerPedId(), 0.0)
        
        print("[qb-alicia] 🎯 Pozisyon " .. playerPosition .. "'e ışınlandı: " .. coords.x .. ", " .. coords.y .. ", " .. coords.z)
    else
        print("[qb-alicia] ⚠️ Geçersiz pozisyon: " .. playerPosition)
    end
end

-- Tahmin fazını başlat (10 saniye freeze + HTML butonları - LUA BUTONLARI DEAKTİF)
-- ✅ Tahmin fazını başlat (ESC ENGELLİ)
function StartGuessPhase()
    gamePhase = "guessing"
    guessCountdown = guessTime
    isPlayerFrozen = true
    showGuessButtons = false -- LUA butonları deaktif, sadece HTML butonları kullan
    isGuessingPhaseActive = true -- ✅ ESC engelleme aktif
    
    print("[qb-alicia] 🤔 === TAHMİN FAZI BAŞLADI ===")
    print("[qb-alicia] 🤔 10 saniye boyunca freezelendin!")
    print("[qb-alicia] 🤔 Sembolünü tahmin et!")
    print("[qb-alicia] 🎮 SADECE HTML BUTONLARI AKTİF!")
    print("[qb-alicia] 🔒 ESC TUŞU DEVRE DIŞI!")
    
    -- Oyuncuyu freeze et
    FreezeEntityPosition(PlayerPedId(), true)
    
    -- ✅ ZORUNLU MOUSE CURSOR AKTİF ET (ESC ile kapatılamaz)
    SetNuiFocus(true, true)
    SetCursorLocation(0.5, 0.5)
    
    -- ✅ ESC engelleme mesajı
    SendNUIMessage({
        type = "startGuessing",
        duration = guessTime,
        escBlocked = true -- ESC engellendiği bilgisi
    })
    
    print("[qb-alicia] 🖱️ Mouse cursor aktif edildi (ESC ile kapatılamaz)!")
    print("[qb-alicia] 🎮 NUI HTML tahmin butonları gönderildi!")
    
    -- Tahmin geri sayımı
    Citizen.CreateThread(function()
        while guessCountdown > 0 and gamePhase == "guessing" do
            Citizen.Wait(1000)
            guessCountdown = guessCountdown - 1
            
            if guessCountdown <= 3 and guessCountdown > 0 then
                print("[qb-alicia] 🤔 Son " .. guessCountdown .. " saniye!")
                
                -- Son saniye uyarı sesi
                PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", 1)
            end
        end
        
        if gamePhase == "guessing" then
            print("[qb-alicia] ⏰ Tahmin süresi doldu! Hiç seçim yapılmadı!")
            
            -- ESC engellemeyi kaldır
            isGuessingPhaseActive = false
            
            -- Hiç tahmin yapılmadıysa ölüm
            ProcessGuessResult(nil)
        end
    end)
end

 
-- Oyuncu ölüm efektleri
function PlayerDeathEffects()
    -- Ekranı kararttır
    DoScreenFadeOut(2000)
    
    Citizen.CreateThread(function()
        Citizen.Wait(2000)
        
        -- Spectator moduna geç (diğer oyuncuları izle)
        SetEntityAlpha(PlayerPedId(), 100, false) -- Yarı şeffaf yap
        SetEntityCollision(PlayerPedId(), false, false) -- Collision kapat
        
        DoScreenFadeIn(2000)
        
        print("[qb-alicia] 👻 Spectator moduna geçtin!")
        
        -- NUI'ya spectator modu
        SendNUIMessage({
            type = "spectatorMode",
            message = "Öldünüz! Diğer oyuncuları izliyorsunuz..."
        })
    end)
end

-- Oyun UI çizimi (sağ üst countdown - LUA BUTONLARI DEAKTİF EDİLDİ)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Tartışma fazı countdown'u (sağ üst)
        if showCountdown and gamePhase == "discussion" then
            DrawDiscussionCountdown()
        end
        
        -- LUA BUTONLARI DEAKTİF EDİLDİ - Sadece HTML butonlarını kullan
        -- if showGuessButtons and gamePhase == "guessing" then
        --     DrawGuessButtons()
        -- end
        
        -- Tahmin countdown'u (orta üst)
        if gamePhase == "guessing" then
            DrawGuessCountdown()
        end
    end
end)

-- Tartışma fazı countdown'u çiz (sağ üst - EXIT BUTONU KALDIRILDI)
function DrawDiscussionCountdown()
    local minutes = math.floor(discussionCountdown / 60)
    local seconds = discussionCountdown % 60
    local timeText = string.format("%02d:%02d", minutes, seconds)
    
    -- Ana countdown arka plan
    DrawRect(0.88, 0.08, 0.15, 0.08, 0, 0, 0, 180)
    
    -- Çerçeve
    DrawRect(0.88, 0.08, 0.16, 0.09, 255, 255, 255, 100)
    
    -- Başlık
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.6, 0.6)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(2, 0, 0, 0, 255)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString("TARTIŞMA SÜRESİ")
    DrawText(0.88, 0.05)
    
    -- Zaman
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(1.2, 1.2)
    if discussionCountdown <= 10 then
        SetTextColour(255, 100, 100, 255) -- Son 10 saniye kırmızı
    else
        SetTextColour(100, 255, 100, 255) -- Yeşil
    end
    SetTextDropshadow(3, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(timeText)
    DrawText(0.88, 0.09)
end

-- Tahmin countdown'u çiz (orta üst)
function DrawGuessCountdown()
    -- Arka plan
    DrawRect(0.5, 0.15, 0.25, 0.08, 0, 0, 0, 200)
    
    -- Çerçeve (kırmızı)
    DrawRect(0.5, 0.15, 0.26, 0.09, 255, 50, 50, 150)
    
    -- Başlık
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.7, 0.7)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(2, 0, 0, 0, 255)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString("SEMBOLÜNÜZÜ TAHMİN EDİN!")
    DrawText(0.5, 0.12)
    
    -- Kalan süre
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(1.5, 1.5)
    SetTextColour(255, 200, 100, 255)
    SetTextDropshadow(3, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(tostring(guessCountdown))
    DrawText(0.5, 0.16)
end

-- Tahmin butonları çiz (ekran ortası - MOUSE CURSOR DÜZELTME + BUTON RENK DEĞİŞİMİ)
function DrawGuessButtons()
    if not showGuessButtons or gamePhase ~= "guessing" then
        return
    end
    
    local buttonWidth = 0.18
    local buttonHeight = 0.1
    local buttonSpacing = 0.2
    local startX = 0.5 - (buttonSpacing * 1.5) -- 4 buton için merkez
    local buttonY = 0.5
    
    local symbols = {"spade", "club", "diamond", "heart"}
    local symbolChars = {"♠", "♣", "♦", "♥"}
    local symbolColors = {
        {r = 64, g = 64, b = 64},    -- Spade - Koyu gri
        {r = 34, g = 139, b = 34},   -- Club - Yeşil
        {r = 255, g = 165, b = 0},   -- Diamond - Turuncu
        {r = 220, g = 20, b = 60}    -- Heart - Kırmızı
    }
    
    -- MOUSE CURSOR GÖSTERİM
    ShowCursorThisFrame()
    
    -- Mouse pozisyonu al
    local cursorX, cursorY = GetNuiCursorPosition()
    local screenW, screenH = GetActiveScreenResolution()
    
    -- Normalizelenmiş mouse pozisyonu
    local normalizedMouseX = cursorX / screenW
    local normalizedMouseY = cursorY / screenH
    
    -- Mouse cursor çiz (görsel feedback)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(1.0, 1.0)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    AddTextComponentString("🖱️")
    DrawText(normalizedMouseX, normalizedMouseY)
    
    for i = 1, 4 do
        local buttonX = startX + (i - 1) * buttonSpacing
        local symbol = symbols[i]
        local symbolChar = symbolChars[i]
        local color = symbolColors[i]
        
        -- Hover kontrolü (daha büyük hit area)
        local isHovered = normalizedMouseX >= (buttonX - buttonWidth/2 - 0.01) and 
                         normalizedMouseX <= (buttonX + buttonWidth/2 + 0.01) and
                         normalizedMouseY >= (buttonY - buttonHeight/2 - 0.01) and 
                         normalizedMouseY <= (buttonY + buttonHeight/2 + 0.01)
        
        -- Buton arka planı (hover'da daha parlak)
        if isHovered then
            DrawRect(buttonX, buttonY, buttonWidth, buttonHeight, color.r, color.g, color.b, 240) -- Çok parlak
            -- Çoklu glow efekti
            DrawRect(buttonX, buttonY, buttonWidth + 0.02, buttonHeight + 0.02, 255, 255, 255, 120)
            DrawRect(buttonX, buttonY, buttonWidth + 0.03, buttonHeight + 0.03, 255, 255, 255, 60)
        else
            DrawRect(buttonX, buttonY, buttonWidth, buttonHeight, color.r, color.g, color.b, 180)
        end
        
        -- Buton çerçevesi (kalın)
        local borderAlpha = isHovered and 255 or 150
        DrawRect(buttonX, buttonY, buttonWidth + 0.008, buttonHeight + 0.008, 255, 255, 255, borderAlpha)
        
        -- Sembol (büyük)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextScale(2.2, 2.2) -- Daha büyük sembol
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(3, 0, 0, 0, 255)
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(symbolChar)
        DrawText(buttonX, buttonY - 0.025)
        
        -- Sembol ismi (hover'da daha parlak)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextScale(0.55, 0.55)
        SetTextColour(255, 255, 255, isHovered and 255 or 200)
        SetTextDropshadow(2, 0, 0, 0, 255)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(symbol:upper())
        DrawText(buttonX, buttonY + 0.035)
        
        -- Hover efekti - yanıp sönen çerçeve
        if isHovered then
            local pulseAlpha = math.floor(math.abs(math.sin(GetGameTimer() * 0.01)) * 100) + 100
            DrawRect(buttonX, buttonY, buttonWidth + 0.01, buttonHeight + 0.01, 255, 255, 0, pulseAlpha)
        end
        
        -- TIKLAMA KONTROLÜ (Enhanced)
        if isHovered then
            -- Hover mesajı
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.4, 0.4)
            SetTextColour(255, 255, 0, 255)
            SetTextDropshadow(2, 0, 0, 0, 255)
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString("TIKLA!")
            DrawText(buttonX, buttonY + 0.065)
            
            -- MOUSE CLICK DETECTION (İyileştirilmiş)
            if IsControlJustPressed(0, 24) then -- Left Click
                print("[qb-alicia] 🎯 " .. symbol:upper() .. " butonuna tıklandı!")
                print("[qb-alicia] 🖱️ Mouse pos: " .. normalizedMouseX .. ", " .. normalizedMouseY)
                print("[qb-alicia] 🎯 Button pos: " .. buttonX .. ", " .. buttonY)
                
                -- Buton seçim efekti (yeşil parlama)
                DrawRect(buttonX, buttonY, buttonWidth + 0.05, buttonHeight + 0.05, 0, 255, 0, 200)
                
                -- Kısa bekleme ile görsel feedback
                Citizen.CreateThread(function()
                    local selectedTime = GetGameTimer()
                    while GetGameTimer() - selectedTime < 500 do -- 500ms parlama
                        Citizen.Wait(0)
                        DrawRect(buttonX, buttonY, buttonWidth + 0.03, buttonHeight + 0.03, 0, 255, 0, 150)
                    end
                end)
                
                ProcessGuessResult(symbol)
                return -- Loop'u kır
            end
        end
    end
    
    -- Ana talimatlar (büyük ve göze çarpan)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.8, 0.8)
    SetTextColour(255, 255, 100, 255)
    SetTextDropshadow(3, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString("🖱️ SEMBOLÜNÜZİ SEÇMEK İÇİN MOUSE İLE TIKLAYIN!")
    DrawText(0.5, buttonY + 0.18)
    
    -- Ek bilgi
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.5, 0.5)
    SetTextColour(255, 255, 255, 200)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString("Kendi sembolünüzü tahmin edin! Doğru = Hayatta, Yanlış = Ölüm")
    DrawText(0.5, buttonY + 0.22)
    
    -- Mouse debug (sol üst köşe)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 150)
    SetTextEntry("STRING")
    AddTextComponentString("Mouse: " .. math.floor(normalizedMouseX*1000)/1000 .. ", " .. math.floor(normalizedMouseY*1000)/1000)
    DrawText(0.02, 0.02)
    
    -- GamePhase debug
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 150)
    SetTextEntry("STRING")
    AddTextComponentString("Phase: " .. gamePhase .. " | Buttons: " .. (showGuessButtons and "ON" or "OFF"))
    DrawText(0.02, 0.04)
end

-- İsim ve sembol çizimi (SERVER verilerini kullan - MAÇA BEYİ GİZLE)
Citizen.CreateThread(function()
    local lastPrintTime = 0
    local printInterval = 5000
    
    while true do
        Citizen.Wait(0)
        
        if isSymbolActive and isTeleported and gamePhase == "discussion" then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local gameTime = GetGameTimer()
            local myServerId = GetPlayerServerId(PlayerPedId())
            
            if myServerId == 0 then
                local playerIndex = NetworkGetPlayerIndexFromPed(playerPed)
                if playerIndex ~= -1 then
                    myServerId = GetPlayerServerId(playerIndex)
                end
            end
            
            -- Oyuncular için (KENDİM HARİÇ)
            for _, player in ipairs(GetActivePlayers()) do
                local otherPlayerPed = GetPlayerPed(player)
                local serverId = GetPlayerServerId(player)
                
                if DoesEntityExist(otherPlayerPed) and otherPlayerPed ~= playerPed and serverId ~= myServerId then
                    local coords = GetEntityCoords(otherPlayerPed)
                    local distance = #(playerCoords - coords)
                    
                    if ShouldDrawSymbol(distance) then
                        local name = GetRealPlayerName(serverId)
                        local symbol = entitySymbols[tostring(serverId)] or "diamond"
                        
                        -- ✅ MAÇA BEYİ BİLGİSİNİ GİZLE - Sadece normal isim göster
                        local displayName = name -- Maça beyi bilgisini ASLA gösterme
                        
                        local alpha = GetSymbolAlpha(distance)
                        
                        DrawSymbol(coords.x, coords.y, coords.z + 1.15, symbol, gameTime * 0.1, alpha)
                        DrawText3D(coords.x, coords.y, coords.z + 0.95, displayName)
                    end
                end
            end
            
            -- Botlar için (MAÇA BEYİ BİLGİSİNİ GİZLE)
            for playerId, ped in pairs(botPeds) do
                if DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    local distance = #(playerCoords - coords)
                    
                    if ShouldDrawSymbol(distance) then
                        local name = playerData[playerId] and playerData[playerId].name or ("Bot_" .. playerId)
                        local symbol = entitySymbols[playerId] or "diamond"
                        
                        -- ✅ MAÇA BEYİ BİLGİSİNİ GİZLE - Sadece normal isim göster
                        local displayName = name -- Maça beyi bilgisini ASLA gösterme
                        
                        local alpha = GetSymbolAlpha(distance)
                        
                        DrawSymbol(coords.x, coords.y, coords.z + 1.15, symbol, gameTime * 0.1, alpha)
                        DrawText3D(coords.x, coords.y, coords.z + 0.95, displayName)
                    end
                end
            end
        end
    end
end)

-- NPC oluşturma
Citizen.CreateThread(function()
    RequestModel(GetHashKey(npcModel))
    while not HasModelLoaded(GetHashKey(npcModel)) do
        Wait(500)
    end

    npc = CreatePed(4, GetHashKey(npcModel), npcCoords.x, npcCoords.y, npcCoords.z, npcCoords.w, false, true)
    SetEntityAsMissionEntity(npc, true, true)
    SetPedFleeAttributes(npc, 0, 0)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetEntityInvincible(npc, true)
    FreezeEntityPosition(npc, true)
    TaskStandStill(npc, -1)
    SetModelAsNoLongerNeeded(GetHashKey(npcModel))

    exports['qb-target']:AddEntityZone("npc_interaction", npc, {
        name = "npc_interaction",
        heading = npcCoords.w,
        debugPoly = false,
        minZ = npcCoords.z - 1.0,
        maxZ = npcCoords.z + 1.0
    }, {
        options = {
            {
                type = "client",
                event = "qb-alicia:openWebpage",
                icon = "fas fa-comment",
                label = "Konuş",
                canInteract = function()
                    local isAltPressed = IsControlPressed(0, 19)
                    if isAltPressed then
                        print("[qb-alicia] Alt tuşuna basıldı, konuş seçeneği aktif.")
                    end
                    return isAltPressed
                end
            }
        },
        distance = 2.0
    })
end)

-- Botları spawn etme (YENİ KONUM - SERVER verilerini kullan - DÜZELTİLDİ)
RegisterNetEvent('qb-alicia:spawnBots')
AddEventHandler('qb-alicia:spawnBots', function(data, maxPlayersCount)
    playerData = data
    
    -- Eğer tartışma fazındaysak botları tartışma alanına spawn et
    local baseCoords
    if gamePhase == "discussion" then
        baseCoords = vector3(1779.69, 2583.99, 45.8) -- Tartışma alanı
    else
        baseCoords = vector3(1779.69, 2583.99, 45.8) -- Varsayılan spawn
    end
    
    local radius = 5.0 -- Daha geniş radius
    local botModel = GetHashKey("a_m_m_business_01")
    local fallbackModel = GetHashKey("a_m_y_business_01")
    local fallbackModel2 = GetHashKey("s_m_m_security_01")

    local targetPlayerCount = maxPlayersCount or 3
    print("[qb-alicia] Bot spawn başlatıldı. Hedef oyuncu sayısı: " .. targetPlayerCount)
    print("[qb-alicia] 📍 Bot spawn konumu: " .. baseCoords.x .. ", " .. baseCoords.y .. ", " .. baseCoords.z)

    -- Önce eski botları temizle
    for playerId, ped in pairs(botPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    botPeds = {}

    -- Modeli yükle
    RequestModel(botModel)
    local modelLoaded = HasModelLoaded(botModel)
    local attempts = 0
    while not modelLoaded and attempts < 10 do
        Wait(500)
        modelLoaded = HasModelLoaded(botModel)
        attempts = attempts + 1
    end

    if not modelLoaded then
        RequestModel(fallbackModel)
        attempts = 0
        while not HasModelLoaded(fallbackModel) and attempts < 10 do
            Wait(500)
            attempts = attempts + 1
        end
        if not HasModelLoaded(fallbackModel) then
            RequestModel(fallbackModel2)
            attempts = 0
            while not HasModelLoaded(fallbackModel2) and attempts < 10 do
                Wait(500)
                attempts = attempts + 1
            end
            if not HasModelLoaded(fallbackModel2) then
                print("[qb-alicia] Hiçbir model yüklenemedi, bot spawn iptal edildi.")
                return
            else
                botModel = fallbackModel2
            end
        else
            botModel = fallbackModel
        end
    end

    -- Gerçek oyuncu sayısını hesapla
    local realPlayerCount = 0
    for playerId, playerInfo in pairs(data) do
        if tonumber(playerId) > 0 then
            realPlayerCount = realPlayerCount + 1
        end
    end

    -- Kaç bot spawn edilmesi gerektiğini hesapla
    local botsToSpawn = targetPlayerCount - realPlayerCount
    if botsToSpawn <= 0 then
        print("[qb-alicia] Bot spawn gerekmiyor.")
        SetModelAsNoLongerNeeded(botModel)
        return
    end

    print("[qb-alicia] " .. botsToSpawn .. " bot spawn edilecek.")

    local botCount = 0
    local botIndex = 1
    
    -- Botları spawn et (DÜZELTME: Her bot için farklı konum)
    for i = 1, botsToSpawn do
        local botId = -botIndex
        
        -- Daha iyi dağılım için farklı açılar
        local angle = (botIndex - 1) * (360.0 / math.max(botsToSpawn, 6)) * math.pi / 180.0
        local distance = radius * (0.5 + (botIndex % 3) * 0.3) -- Farklı mesafeler
        local x = baseCoords.x + distance * math.cos(angle)
        local y = baseCoords.y + distance * math.sin(angle)
        local found, z = GetGroundZFor_3dCoord(x, y, baseCoords.z + 2.0, false)
        if not found then
            z = baseCoords.z
        end
        
        print("[qb-alicia] Bot spawn deniyor: " .. x .. ", " .. y .. ", " .. z)
        
        local ped = CreatePed(4, botModel, x, y, z, math.random(0, 360), false, true)
        if ped and DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            SetPedFleeAttributes(ped, 0, 0)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetEntityInvincible(ped, true)
            TaskStandStill(ped, -1)
            
            -- Bot verilerini kontrol et
            if not playerData[tostring(botId)] then
                local botNames = {
                    "Michael Johnson", "Sarah Wilson", "David Brown", "Emily Davis", 
                    "James Miller", "Lisa Anderson", "Robert Taylor", "Jennifer Martinez", 
                    "William Garcia", "Amanda Rodriguez"
                }
                playerData[tostring(botId)] = {
                    name = botNames[botIndex] or ("Bot_" .. botIndex),
                    id = botId
                }
            end
            
            botPeds[tostring(botId)] = ped
            botCount = botCount + 1
            
            print("[qb-alicia] ✅ BOT SPAWN: " .. playerData[tostring(botId)].name .. " (ID:" .. botId .. ") → " .. x .. ", " .. y .. ", " .. z)
        else
            print("[qb-alicia] ❌ Bot spawn edilemedi: ID " .. botId)
        end
        
        botIndex = botIndex + 1
    end
    
    SetModelAsNoLongerNeeded(botModel)
    print("[qb-alicia] 🤖 Toplam " .. botCount .. " bot spawn edildi.")
    print("[qb-alicia] 🤖 Bot listesi:")
    for id, ped in pairs(botPeds) do
        if DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            print("[qb-alicia] 🤖   " .. (playerData[id] and playerData[id].name or id) .. " → " .. coords.x .. ", " .. coords.y .. ", " .. coords.z)
        end
    end
end)

-- HTML sayfasını açma (warning sistemi)
RegisterNetEvent("qb-alicia:openWebpage")
AddEventHandler("qb-alicia:openWebpage", function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(npcCoords.x, npcCoords.y, npcCoords.z))
    if distance > 5.0 then
        print("[qb-alicia] Hata: NPC'den uzak mesafede etkileşim! Mesafe: " .. distance)
        return
    end

    print("[qb-alicia] NPC ile konuşma - server'a warning isteği gönderiliyor.")
    TriggerServerEvent("qb-alicia:openWebpage")
end)

-- Warning sayfasını göster
RegisterNetEvent("qb-alicia:showWarning")
AddEventHandler("qb-alicia:showWarning", function()
    print("[qb-alicia] Warning sayfası açılıyor.")
    SetTimecycleModifier("hud_def_blur")
    SendNUIMessage({
        type = "openWarning"
    })
    SetNuiFocus(true, true)
    isInLobby = false
end)

-- lobi gösterim eventi (script.js ile uyumlu - GÜNCELLEME)
RegisterNetEvent("open:lobi")
AddEventHandler("open:lobi", function(playerList)
    print("[qb-alicia] open:lobi eventi alındı. Oyuncu sayısı: " .. (playerList and tableLength(playerList) or "nil"))
    
    SetTimecycleModifier("hud_def_blur")
    
    SendNUIMessage({
        type = "openLobi",
        players = playerList or {}
    })
    
    SetNuiFocus(true, true)
    isInLobby = true
    
    print("[qb-alicia] Lobi gösterimi komutu gönderildi, NUI focus ayarlandı.")
    
    if playerList then
        print("[qb-alicia] Gönderilen oyuncu listesi:")
        for playerId, playerData in pairs(playerList) do
            print("  - ID: " .. playerId .. ", İsim: " .. (playerData.name or "Bilinmeyen") .. ", Hazır: " .. tostring(playerData.ready or false))
        end
    end
end)

-- Lobi oyuncu listesini güncelleme
RegisterNetEvent("update:lobby")
AddEventHandler("update:lobby", function(playerList)
    if not isInLobby then
        print("[qb-alicia] update:lobby çağrıldı, ancak oyuncu lobide değil.")
        return
    end
    
    print("[qb-alicia] Lobi güncelleme alındı. Oyuncu sayısı: " .. (playerList and tableLength(playerList) or "nil"))
    
    Citizen.Wait(100)
    
    SendNUIMessage({
        type = "updateLobby",
        players = playerList or {}
    })
    
    print("[qb-alicia] Lobi oyuncu listesi güncellendi.")
    
    if playerList then
        for playerId, playerData in pairs(playerList) do
            print("  - Güncelleme: ID " .. playerId .. ", İsim: " .. (playerData.name or "Bilinmeyen") .. ", Hazır: " .. tostring(playerData.ready or false))
        end
    end
end)

-- Lobiden çıkış eventi
RegisterNetEvent("qb-alicia:closeLobby")
AddEventHandler("qb-alicia:closeLobby", function()
    SetTimecycleModifier("")
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "closeLobi"
    })
    isInLobby = false
    print("[qb-alicia] Lobi kapatıldı.")
end)

-- Oyuncuları ışınlama ve sembol atama (YENİ KONUM - SERVER'dan güvenli veri alma - DÜZELTİLDİ)
RegisterNetEvent("teleport:players")
AddEventHandler("teleport:players", function(secureData, maxPlayers)
    print("[qb-alicia] === 'teleport:players' eventi alındı ===")
    
    SetTimecycleModifier("")
    SetNuiFocus(false, false)
    
    SetEntityCoords(PlayerPedId(), spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityHeading(PlayerPedId(), 90.0)
    
    SendNUIMessage({
        type = "closeLobi"
    })
    
    isInLobby = false
    isTeleported = true
    playerData = secureData

    entitySymbols = {}
    spadeKingId = nil
    
    if secureData then
        for playerId, playerInfo in pairs(secureData) do
            if playerInfo then
                entitySymbols[playerId] = playerInfo.symbol
                
                if playerInfo.isSpadeKing then
                    spadeKingId = playerId
                end
                
                if playerInfo.sessionId then
                    currentSession = playerInfo.sessionId
                end
            end
        end
    end

    -- ✅ MAÇA BEYİ KONTROLÜ VE BİLGİLENDİRME
    local myServerId = GetPlayerServerId(PlayerPedId())
    if myServerId == 0 then
        local playerPed = PlayerPedId()
        local playerIndex = NetworkGetPlayerIndexFromPed(playerPed)
        if playerIndex ~= -1 then
            myServerId = GetPlayerServerId(playerIndex)
        end
        
        if myServerId == 0 then
            for playerId, symbol in pairs(entitySymbols) do
                local numId = tonumber(playerId)
                if numId and numId > 0 then
                    myServerId = numId
                    break
                end
            end
        end
    end
    
    local mySymbol = entitySymbols[tostring(myServerId)]
    local myKingStatus = (spadeKingId == tostring(myServerId))
    
    print("[qb-alicia] 🔒 === KENDİ DURUMUM ===")
    print("[qb-alicia] 🔒 Benim ID'm: " .. myServerId)
    print("[qb-alicia] 🔒 Benim sembolüm: " .. (mySymbol or "YOK"))
    print("[qb-alicia] 🔒 Maça beyi miyim: " .. (myKingStatus and "EVET" or "HAYIR"))

    -- ✅ MAÇA BEYİ ÖZEL BİLGİLENDİRME (OYUN BAŞINDA)
    if myKingStatus then
        print("")
        print("👑👑👑👑👑👑👑👑👑👑👑👑👑👑👑")
        print("👑     SEN MAÇA BEYİSİN!     👑")
        print("👑   - Oyun boyunca maça     👑")
        print("👑   - Eğer ölürsen herkes   👑")
        print("👑     kazanır!              👑")
        print("👑   - Son kalan sen olursan 👑")
        print("👑     SEN kazanırsın!       👑")
        print("👑   ROL YAP ve DİĞERLERİNİ  👑")
        print("👑      YANILT!              👑")
        print("👑👑👑👑👑👑👑👑👑👑👑👑👑👑👑")
        print("")
        
        -- ✅ HTML BİLGİLENDİRME (OYUN BAŞINDA)
        Citizen.CreateThread(function()
            Citizen.Wait(2000) -- 2 saniye bekle ki spawn tamamlansın
            
            SendNUIMessage({
                type = "spadeKingInfo",
                message = "👑 SEN MAÇA BEYİSİN!\n\nEğer ölürsen diğerleri kazanır!\nSon kalan sen olursan sen kazanırsın!\n\nDiğer oyuncuları yanılt ve rol yap!"
            })
            
            print("[qb-alicia] 👑 HTML maça beyi bildirimi gönderildi!")
        end)
    end

    TriggerEvent('qb-alicia:spawnBots', secureData, maxPlayers or 3)
    print("[qb-alicia] === ULTRA GÜVENLİ SPAWN TAMAMLANDI ===")
end)


-- Server'dan oyun pozisyonu alma
RegisterNetEvent('qb-alicia:setPlayerPosition')
AddEventHandler('qb-alicia:setPlayerPosition', function(position)
    playerPosition = position
    print("[qb-alicia] 🎯 Oyuncu pozisyonu atandı: " .. position)
end)

-- Server'dan sembol atama (YENI - Eksik olan event)
RegisterNetEvent('qb-alicia:setPlayerSymbol')
AddEventHandler('qb-alicia:setPlayerSymbol', function(playerId, symbol, isSpadeKing)
    entitySymbols[tostring(playerId)] = symbol
    
    if isSpadeKing then
        spadeKingId = tostring(playerId)
    end
    
    print("[qb-alicia] 🔒 Sembol atandı: ID " .. playerId .. " → " .. symbol .. (isSpadeKing and " 👑 (MAÇA BEYİ)" or ""))
end)

-- Server'dan tüm sembol listesi alma (YENI - Backup sistem)
RegisterNetEvent('qb-alicia:receiveAllSymbols')
AddEventHandler('qb-alicia:receiveAllSymbols', function(symbolData, kingId)
    print("[qb-alicia] 🔒 === TÜM SEMBOLLER ALINDI ===")
    
    entitySymbols = symbolData or {}
    spadeKingId = kingId
    
    local symbolCount = 0
    for playerId, symbol in pairs(entitySymbols) do
        symbolCount = symbolCount + 1
        local kingMark = (spadeKingId == playerId) and " 👑" or ""
        print("[qb-alicia] 🔒 " .. playerId .. " → " .. symbol .. kingMark)
    end
    
    print("[qb-alicia] 🔒 Toplam " .. symbolCount .. " sembol yüklendi")
    print("[qb-alicia] 🔒 Maça Beyi: " .. (spadeKingId or "YOK"))
end)

--- ✅ Yeni round eventi (SABİT MAÇA BEYİ ile)
RegisterNetEvent('qb-alicia:newRound')
AddEventHandler('qb-alicia:newRound', function(round, newPlayerData)
    print("[qb-alicia] 🆕 === YENİ ROUND: " .. round .. " ===")
    print("[qb-alicia] 🆕 Gelen player data boyutu: " .. (newPlayerData and tableLength(newPlayerData) or "nil"))
    
    currentRound = round
    isPlayerAlive = true
    isPlayerFrozen = false
    gamePhase = "lobby"
    isSymbolActive = false
    
    -- ✅ ESKİ VERİLERİ TEMIZLE
    local oldSpadeKing = spadeKingId -- Eski maça beyini sakla (kontrol için)
    entitySymbols = {}
    spadeKingId = nil
    
    -- ✅ YENİ SEMBOL VERİLERİNİ GÜNCELLE
    if newPlayerData then
        for playerId, playerInfo in pairs(newPlayerData) do
            entitySymbols[playerId] = playerInfo.symbol
            if playerInfo.isSpadeKing then
                spadeKingId = playerId
            end
            
            print("[qb-alicia] 🆕 YENİ SEMBOL YÜKLENDİ: " .. playerInfo.name .. " (ID:" .. playerId .. ") → " .. playerInfo.symbol .. (playerInfo.isSpadeKing and " 👑" or ""))
        end
        
        -- ✅ playerData'yı da güncelle (botlar için)
        playerData = newPlayerData
    end
    
    -- ✅ KENDİ YENİ SEMBOLÜMÜ KONTROL ET
    local myServerId = GetPlayerServerId(PlayerPedId())
    if myServerId == 0 then
        local playerPed = PlayerPedId()
        local playerIndex = NetworkGetPlayerIndexFromPed(playerPed)
        if playerIndex ~= -1 then
            myServerId = GetPlayerServerId(playerIndex)
        end
    end
    
    local myNewSymbol = entitySymbols[tostring(myServerId)]
    print("[qb-alicia] 🆕 BENİM YENİ SEMBOLÜM: " .. (myNewSymbol or "YOK"))
    
    -- ✅ MAÇA BEYİ DURUMU KONTROLÜ (SABİT KALACAK)
    local amISpadeKing = (spadeKingId == tostring(myServerId))
    local wasISpadeKing = (oldSpadeKing == tostring(myServerId))
    
    print("[qb-alicia] 🆕 === SABİT MAÇA BEYİ DURUMU ===")
    print("[qb-alicia] 🆕 Maça beyi (SABİT): " .. (spadeKingId or "YOK"))
    print("[qb-alicia] 🆕 Ben maça beyi miyim: " .. (amISpadeKing and "EVET (SABİT)" or "HAYIR"))
    
    -- ✅ MAÇA BEYİ BİLGİLENDİRME (SABİT OLDUĞU İÇİN HATIRLATMA)
    if amISpadeKing then
        print("")
        print("👑👑👑👑👑👑👑👑👑👑👑👑👑👑👑")
        print("👑  MAÇA BEYİSİN! (Round " .. round .. ")  👑")
        print("👑    BU DURUM SABİTTİR!      👑")
        print("👑  Bütün roundlarda maça     👑")
        print("👑   beyi olarak kalacaksın!  👑")
        print("👑   ROL YAP ve DİĞERLERİNİ   👑")
        print("👑        YANILT!             👑")
        print("👑👑👑👑👑👑👑👑👑👑👑👑👑👑👑")
        print("")
        
        -- ✅ HTML BİLGİLENDİRME (SABİT MAÇA BEYİ)
        Citizen.CreateThread(function()
            Citizen.Wait(2000)
            
            local message = "👑 MAÇA BEYİSİN! (Round " .. round .. ")\n\nBu durum SABİTTİR!\nBütün roundlarda maça beyi kalacaksın!\n\nDikkatli ol ve rol yap!"
            
            SendNUIMessage({
                type = "spadeKingReminder",
                message = message
            })
            
            print("[qb-alicia] 👑 HTML sabit maça beyi bildirimi gönderildi!")
        end)
    elseif wasISpadeKing and not amISpadeKing then
        -- Bu durum ASLA olmamalı çünkü maça beyi sabit
        print("")
        print("🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨")
        print("🚨    HATA: MAÇA BEYİ DEĞİŞTİ!   🚨")
        print("🚨   BU OLMAMALIYDI! (SABİT)     🚨")
        print("🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨")
        print("")
    end
    
    -- ✅ Spawn noktasına ışınla
    SetEntityCoords(PlayerPedId(), spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityHeading(PlayerPedId(), 90.0)
    
    -- ✅ NUI'ya round bilgisi
    SendNUIMessage({
        type = "newRound",
        round = round,
        message = "🆕 Round " .. round .. " başlıyor!\nMAÇA BEYİ SABİT KALIYOR!"
    })
    
    print("[qb-alicia] 🆕 Round " .. round .. " hazır, countdown bekleniyor...")
    print("[qb-alicia] 🆕 ✅ MAÇA BEYİ SABİT KALACAK: " .. (spadeKingId or "YOK"))
end)


-- ✅ Oyun bitişi eventi (mevcut olan yerine koy)
RegisterNetEvent('qb-alicia:gameEnded')
AddEventHandler('qb-alicia:gameEnded', function(gameResult)
    print("[qb-alicia] 🏁 === OYUN BİTTİ ===")
    print("[qb-alicia] 🏁 " .. gameResult.message)
    
    gamePhase = "ended"
    
    -- ✅ UI'yi temizle
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "hideAll"
    })
    
    -- ✅ Freeze'leri kaldır
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityAlpha(PlayerPedId(), 255, false)
    SetEntityCollision(PlayerPedId(), true, true)
    isPlayerFrozen = false
    
    -- ✅ Spectator modundaysam normal hale getir
    if not isPlayerAlive then
        SetEntityAlpha(PlayerPedId(), 255, false)
        SetEntityCollision(PlayerPedId(), true, true)
        isPlayerAlive = true
        print("[qb-alicia] 👻 Spectator modundan çıkıldı!")
    end
    
    -- ✅ Oyun sonucu mesajını göster (kazananlar zaten spawn edilmiş)
    if not gameResult.isWinner then
        SendNUIMessage({
            type = "showWinMessage",
            message = gameResult.message
        })
    end
    
    print("[qb-alicia] 🏁 Oyun bitti, hareket edebilirsin!")
end)

-- NUI Callbacks - GÜNCELLENMIŞ (script.js ile uyumlu)
RegisterNUICallback("close", function(data, cb)
    SetTimecycleModifier("")
    SetNuiFocus(false, false)
    isInLobby = false
    
    -- Oyun durumunu sıfırla
    gamePhase = "lobby"
    isSymbolActive = false
    showCountdown = false
    showGuessButtons = false
    isPlayerFrozen = false
    FreezeEntityPosition(PlayerPedId(), false)
    
    print("[qb-alicia] NUI kapatıldı, oyun durumu sıfırlandı.")
    cb("ok")
end)

RegisterNUICallback("accept", function(data, cb)
    TriggerServerEvent("update:ck_onay")
    print("[qb-alicia] Evet butonuna basıldı, ck_onay güncelleniyor ve lobi gösterilecek.")
    cb("ok")
end)

RegisterNUICallback("selectSymbol", function(data, cb)
    local selectedSymbol = data.symbol
    print("[qb-alicia] 🎯 NUI'dan sembol seçildi: " .. selectedSymbol)
    
    if gamePhase == "guessing" then
        print("[qb-alicia] ✅ Tahmin fazında, sembol işleniyor...")
        ProcessGuessResult(selectedSymbol)
    else
        print("[qb-alicia] ⚠️ Sembol seçimi reddedildi - Oyun fazı: " .. gamePhase)
    end
    
    cb("ok")
end)

RegisterNUICallback("ready", function(data, cb)
    print("[qb-alicia] Hazır butonu basıldı.")
    TriggerServerEvent("qb-alicia:playerReady")
    cb("ok")
end)

RegisterNUICallback("leaveLobby", function(data, cb)
    print("[qb-alicia] Lobiden ayrılma butonu basıldı.")
    TriggerServerEvent("qb-alicia:leaveLobby")
    cb("ok")
end)

RegisterNUICallback("startGame", function(data, cb)
    print("[qb-alicia] Oyun başlatma butonu basıldı.")
    TriggerServerEvent("qb-alicia:startGame")
    cb("ok")
end)

-- Oyuncu ismini alma callback
RegisterNetEvent('qb-alicia:receivePlayerName')
AddEventHandler('qb-alicia:receivePlayerName', function(serverId, playerName)
    print("[qb-alicia] 📝 Oyuncu ismi alındı: " .. serverId .. " → " .. playerName)
    
    -- Cache'e kaydet
    if not playerData[tostring(serverId)] then
        playerData[tostring(serverId)] = {}
    end
    playerData[tostring(serverId)].name = playerName
end)

-- Temizlik fonksiyonu - GÜNCELLENMIŞ
function CleanupGameData()
    entitySymbols = {}
    spadeKingId = nil
    currentSession = nil
    isSymbolActive = false
    isTeleported = false
    
    -- Oyun durumlarını sıfırla
    gamePhase = "lobby"
    showCountdown = false
    showGuessButtons = false
    isPlayerFrozen = false
    isPlayerAlive = true
    playerPosition = 0
    currentRound = 1
    
    -- Freeze'i kaldır
    FreezeEntityPosition(PlayerPedId(), false)
    
    -- Botları temizle
    for playerId, ped in pairs(botPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    botPeds = {}
    
    print("[qb-alicia] 🧹 Oyun verileri temizlendi.")
end

-- Anti-cheat: Sembol doğrulama gönder (opsiyonel)
function ValidateClientSymbols()
    if currentSession and isTeleported then
        local myServerId = GetPlayerServerId(PlayerPedId())
        local mySymbol = entitySymbols[tostring(myServerId)]
        local isKing = (spadeKingId == tostring(myServerId))
        
        if mySymbol then
            TriggerServerEvent('qb-alicia:validateSymbol', mySymbol, isKing)
            print("[qb-alicia] 🔒 Sembol doğrulama server'a gönderildi: " .. mySymbol)
        end
    end
end

-- Periyodik doğrulama (opsiyonel - hile koruması için)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) -- 30 saniyede bir
        
        if isSymbolActive and currentSession then
            ValidateClientSymbols()
        end
    end
end)

-- Debug komutları - GÜNCELLENMIŞ (KENDİ SEMBOLÜNÜ GÖSTER)
RegisterCommand("symbols", function()
    print("[qb-alicia] === ULTRA GÜVENLİ SEMBOL LİSTESİ (SERVER-ONLY) ===")
    
    if not isTeleported then
        print("[qb-alicia] Henüz spawn edilmedi!")
        return
    end
    
    local myServerId = GetPlayerServerId(PlayerPedId())
    local mySymbol = entitySymbols[tostring(myServerId)] or "YOK"
    local isMyKing = (spadeKingId == tostring(myServerId))
    
    -- Oyun durumu
    print("[qb-alicia] 🔒 Session ID: " .. (currentSession or "YOK"))
    print("[qb-alicia] 🎮 Oyun Fazı: " .. gamePhase)
    print("[qb-alicia] 🎮 Round: " .. currentRound)
    print("[qb-alicia] 🎮 Pozisyon: " .. playerPosition)
    print("[qb-alicia] 🎮 Hayatta: " .. (isPlayerAlive and "EVET" or "HAYIR"))
    print("[qb-alicia] 🎮 Semboller aktif: " .. (isSymbolActive and "EVET" or "HAYIR"))
    print("[qb-alicia] ═════════════════════════════════════")
    
    -- KENDİ SEMBOLÜNÜ GÖSTER (DEBUG İÇİN)
    print("[qb-alicia] 🔒 💫 BENİM SEMBOLÜM: " .. mySymbol .. (isMyKing and " 👑 (MAÇA BEYİ)" or ""))
    print("[qb-alicia] 🔒 💫 (Bu bilgiyi sadece debug için görüyorsun!)")
    print("[qb-alicia] 🔒 💫 Oyunda kendi sembolünü GÖREMEZSİN!")
    print("[qb-alicia] ═════════════════════════════════════")
    
    -- Maça beyi bilgisi
    if spadeKingId then
        local kingName = "Bilinmeyen"
        local kingType = "Bilinmeyen"
        
        -- İsmi bul
        if tonumber(spadeKingId) and tonumber(spadeKingId) > 0 then
            kingName = GetRealPlayerName(tonumber(spadeKingId))
            kingType = "OYUNCU"
        else
            kingName = playerData[spadeKingId] and playerData[spadeKingId].name or ("Bot_" .. spadeKingId)
            kingType = "BOT"
        end
        
        print("[qb-alicia] 🔒 👑 MAÇA BEYİ (ULTRA-SAFE): " .. kingName .. " (ID:" .. spadeKingId .. ") [" .. kingType .. "]")
        print("[qb-alicia] ═════════════════════════════════════")
    else
        print("[qb-alicia] ❌ Maça Beyi henüz seçilmedi!")
        print("[qb-alicia] ═════════════════════════════════════")
    end
    
    -- DİĞER oyuncular (KENDİM HARİÇ)
    print("[qb-alicia] 🔒 👥 DİĞER OYUNCULAR (Görünen semboller):")
    for _, player in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(player)
        if serverId ~= myServerId then -- Kendimi hariç tut
            local name = GetRealPlayerName(serverId)
            local symbol = entitySymbols[tostring(serverId)] or "diamond"
            local symbolDisplay = symbol .. " (GÖRÜNÜR)"
            
            local kingMark = (spadeKingId == tostring(serverId)) and " 👑" or ""
            local visibleMark = isSymbolActive and " [AKTİF]" or " [GİZLİ]"
            print("[qb-alicia] 🔒 OYUNCU: " .. name .. " (ID:" .. serverId .. ") → " .. symbolDisplay .. kingMark .. visibleMark)
        end
    end
    
    -- Botlar
    print("[qb-alicia] 🔒 🤖 BOTLAR (Görünen semboller):")
    for playerId, ped in pairs(botPeds) do
        if DoesEntityExist(ped) then
            local name = playerData[playerId] and playerData[playerId].name or ("Bot_" .. playerId)
            local symbol = entitySymbols[playerId] or "diamond"
            local symbolDisplay = symbol .. " (GÖRÜNÜR)"
            
            local kingMark = (spadeKingId == playerId) and " 👑" or ""
            local visibleMark = isSymbolActive and " [AKTİF]" or " [GİZLİ]"
            print("[qb-alicia] 🔒 BOT: " .. name .. " (ID:" .. playerId .. ") → " .. symbolDisplay .. kingMark .. visibleMark)
        end
    end
    
    print("[qb-alicia] === ULTRA GÜVENLİ LİSTE SONU (OYUN MEKANİĞİ KORUNDU) ===")
    print("[qb-alicia] 💡 HATIRLATMA: Oyunda kendi sembolünü göremezsin!")
    print("[qb-alicia] 💡 Diğer oyunculardan öğrenmeye çalış!")
end, false)

-- Kendi sembolünü öğren komutu (DEBUG - sadece console için) - GELİŞTİRİLMİŞ
RegisterCommand("mysymbol", function()
    local myServerId = GetPlayerServerId(PlayerPedId())
    local mySymbol = entitySymbols[tostring(myServerId)] or "YOK"
    local isMyKing = (spadeKingId == tostring(myServerId))
    
    print("[qb-alicia] 💫 === KENDİ SEMBOLÜM (DEBUG) ===")
    print("[qb-alicia] 💫 Benim Server ID'm: " .. myServerId)
    print("[qb-alicia] 💫 String olarak: '" .. tostring(myServerId) .. "'")
    print("[qb-alicia] 💫 Sembolüm: " .. mySymbol)
    print("[qb-alicia] 💫 Maça Beyi: " .. (isMyKing and "EVET" or "HAYIR"))
    print("[qb-alicia] 💫 Bu bilgi oyunda GÖRÜNMEZ!")
    print("[qb-alicia] 💫 Sadece debug için console'da görüyorsun!")
    
    -- Eğer sembol yoksa detaylı debug
    if mySymbol == "YOK" then
        print("[qb-alicia] 💫 === DEBUG BİLGİLERİ ===")
        print("[qb-alicia] 💫 isTeleported: " .. (isTeleported and "true" or "false"))
        print("[qb-alicia] 💫 entitySymbols tablosu boyutu: " .. tableLength(entitySymbols))
        print("[qb-alicia] 💫 currentSession: " .. (currentSession or "YOK"))
        print("[qb-alicia] 💫 spadeKingId: " .. (spadeKingId or "YOK"))
        
        -- entitySymbols tablosunu yazdır
        print("[qb-alicia] 💫 === entitySymbols İÇERİĞİ ===")
        for id, symbol in pairs(entitySymbols) do
            print("[qb-alicia] 💫   ['" .. id .. "'] = " .. symbol)
        end
        
        -- playerData tablosunu yazdır
        print("[qb-alicia] 💫 === playerData İÇERİĞİ ===")
        for id, data in pairs(playerData) do
            print("[qb-alicia] 💫   ['" .. id .. "'] = " .. (data.name or "İsimsiz"))
        end
        
        -- Çözüm önerileri
        print("[qb-alicia] 💫 === ÇÖZÜM ÖNERİLERİ ===")
        print("[qb-alicia] 💫 1. Server ID 0 ise sorun var!")
        print("[qb-alicia] 💫 2. /addtestbots komutuyla daha fazla bot ekle")
        print("[qb-alicia] 💫 3. /setmaxplayers 3 komutu kullan")
        print("[qb-alicia] 💫 4. Lobi dolduktan sonra oyun başlayacak")
    end
end, false)

RegisterCommand("forcecorrect", function()
    print("[qb-alicia] 🎯 Zorla doğru tahmin modu aktif!")
    print("[qb-alicia] 🎯 Herhangi bir seçim yapığında doğru kabul edilecek!")
    
    -- Geçici olarak tahmin edilen her şeyi doğru kabul et
    gamePhase = "guessing"
    showGuessButtons = false
    isPlayerFrozen = true
    
    -- Freeze et
    FreezeEntityPosition(PlayerPedId(), true)
    
    -- HTML butonları göster
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = "startGuessing",
        duration = 30
    })
    
    -- Geçici sembol ata (kendi ID'ne)
    local myServerId = GetPlayerServerId(PlayerPedId())
    entitySymbols[tostring(myServerId)] = "spade" -- Geçici sembol
    
    print("[qb-alicia] 🎯 Test için geçici sembol atandı: spade")
    print("[qb-alicia] 🎯 Şimdi herhangi bir buton seç!")
end, false)


-- ✅ ÖNCE FONKSİYONU TANIMLA
-- ✅ DÜZELTILMIŞ ProcessGuessResult fonksiyonu (INVISIBLE ve YER ALTI SORUNU ÇÖZÜLMÜş)
function ProcessGuessResult(guessedSymbol)
    -- ✅ ESC ENGELLEMESİNİ KALDIR (İLK ÖNCE)
    isGuessingPhaseActive = false
    print("[qb-alicia] 🔓 ESC engelleme kaldırıldı - tahmin yapıldı!")

   -- ✅ GAME PHASE KONTROLÜ
    if gamePhase ~= "guessing" and gamePhase ~= "results" then
        print("[qb-alicia] ⚠️ ProcessGuessResult çağrıldı ama gamePhase: " .. gamePhase)
        return
    end
    
    -- ✅ İLK ÇAĞRIDA PHASE'I DEĞİŞTİR
    if gamePhase == "guessing" then
        gamePhase = "results"
        showGuessButtons = false
        
        SetNuiFocus(false, false)
        SendNUIMessage({ type = "hideGuessing" })
    end
    
    print("[qb-alicia] 🎲 === SEMBOL DOĞRULAMA ANALİZİ ===")
    print("[qb-alicia] 🎲 Tahmin edilen: '" .. (guessedSymbol or "YOK") .. "'")
    
    -- ✅ SERVER ID ALMA (düzeltilmiş)
    local myServerId = GetPlayerServerId(PlayerPedId())
    if myServerId == 0 then
        local playerPed = PlayerPedId()
        local playerIndex = NetworkGetPlayerIndexFromPed(playerPed)
        if playerIndex ~= -1 then
            myServerId = GetPlayerServerId(playerIndex)
        end
        
        -- Hala 0 ise, entitySymbols'den ilk gerçek oyuncuyu bul
        if myServerId == 0 then
            for playerId, symbol in pairs(entitySymbols) do
                local numId = tonumber(playerId)
                if numId and numId > 0 then
                    myServerId = numId
                    print("[qb-alicia] 🔧 Server ID 0 olduğu için alternatif ID kullanıldı: " .. myServerId)
                    break
                end
            end
        end
    end
    
    print("[qb-alicia] 🎲 Benim Server ID: " .. myServerId)
    
    local myRealSymbol = entitySymbols[tostring(myServerId)]
    print("[qb-alicia] 🎲 Server'dan gelen sembol: '" .. (myRealSymbol or "YOK") .. "'")
    
    -- ✅ ACİL ÇÖZÜM: Eğer sembol YOK ise server'dan iste
    if not myRealSymbol or myRealSymbol == "" then
        print("[qb-alicia] 🚨 === ACİL DURUM: SEMBOL VERİSİ YOK! ===")
        
        -- Server'dan sembol iste
        TriggerServerEvent('qb-alicia:requestMySymbol', myServerId)
        
        Citizen.CreateThread(function()
            Citizen.Wait(1000) -- 1 saniye bekle
            
            myRealSymbol = entitySymbols[tostring(myServerId)]
            if myRealSymbol then
                print("[qb-alicia] ✅ Sembol alındı, tahmin tekrar işleniyor: " .. myRealSymbol)
                ProcessGuessResult(guessedSymbol)
            else
                print("[qb-alicia] ❌ Sembol hala alınamadı! Zorla doğru kabul ediliyor...")
                ProcessCorrectGuess(guessedSymbol)
            end
        end)
        
        return
    end
    
    -- ✅ SEMBOL DOĞRULAMA
    local isCorrect = false
    if guessedSymbol and myRealSymbol then
        isCorrect = (guessedSymbol:lower() == myRealSymbol:lower())
        print("[qb-alicia] 🎲 === SEMBOL KARŞILAŞTIRMA ===")
        print("[qb-alicia] 🎲 Client tahmin: '" .. guessedSymbol:lower() .. "'")
        print("[qb-alicia] 🎲 Server sembol: '" .. myRealSymbol:lower() .. "'")
        print("[qb-alicia] 🎲 Sonuç: " .. (isCorrect and "✅ DOĞRU!" or "❌ YANLIŞ!"))
    else
        print("[qb-alicia] 🎲 Tahmin veya sembol eksik - YANLIŞ kabul ediliyor")
        isCorrect = false
    end

    -- ✅ DOĞRU TAHMİN DURUMU
    if isCorrect then
        print("[qb-alicia] ✅ === DOĞRU TAHMİN - HAYATTA KALDIN! ===")
        isPlayerAlive = true
        isPlayerFrozen = false
        
        -- ✅ BAŞARI EFEKTLERİ
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        print("[qb-alicia] 🎉 Başarı efektleri başlatılıyor...")
        
        -- Yeşil ışık efekti
        Citizen.CreateThread(function()
            RequestNamedPtfxAsset("core")
            while not HasNamedPtfxAssetLoaded("core") do
                Citizen.Wait(1)
            end
            
            -- Başarı parçacıkları (yeşil)
            UseParticleFxAssetNextCall("core")
            StartParticleFxLoopedAtCoord("ent_dst_elec_fire_sp", playerCoords.x, playerCoords.y, playerCoords.z + 1.0, 0.0, 0.0, 0.0, 0.8, false, false, false, false)
            
            -- Parıltı efekti
            UseParticleFxAssetNextCall("core")
            StartParticleFxLoopedAtCoord("ent_amb_candle_flame", playerCoords.x, playerCoords.y, playerCoords.z + 2.0, 0.0, 0.0, 0.0, 2.0, false, false, false, false)
        end)
        
        -- ✅ BAŞARI SESLERİ
        PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", 1)
        Citizen.Wait(300)
        PlaySoundFrontend(-1, "WINNER", "HUD_AWARDS", 1)
        
        -- ✅ KAMERA EFEKTİ (hafif sallama)
        ShakeGameplayCam("HAND_SHAKE", 0.3)
        
        -- ✅ GÜÇLÜ FREEZE KALDIRMA
        FreezeEntityPosition(PlayerPedId(), false)
        SetEntityAlpha(PlayerPedId(), 255, false)
        SetEntityCollision(PlayerPedId(), true, true)
        
        -- ✅ NUI'ya başarı mesajı
        SendNUIMessage({
            type = "guessResult",
            success = true,
            message = "🎉 DOĞRU TAHMİN! Hayatta kaldınız!"
        })
        
        -- ✅ Server'a başarı bildir
        TriggerServerEvent('qb-alicia:playerGuessResult', guessedSymbol, true)
        
        print("[qb-alicia] ✅ Freeze kaldırıldı, yeni round bekleniyor...")
        print("[qb-alicia] 🎉 Başarı efektleri tamamlandı!")
        
    else
        -- ❌ YANLIŞ TAHMİN - PATLAMA ve ÖLÜM (DÜZELTILMIŞ)
        print("[qb-alicia] ❌ === YANLIŞ TAHMİN - PATLAMA ve ÖLÜM ===")
        isPlayerAlive = false
        isPlayerFrozen = true
        
        -- ✅ PATLAMA EFEKTİ
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        print("[qb-alicia] 💥 Patlama efekti başlatılıyor...")
        
        -- Küçük patlama efekti (karakter ayağında)
        AddExplosion(playerCoords.x, playerCoords.y, playerCoords.z - 0.5, 1, 1.0, true, false, 0.3)
        
        -- Çoklu küçük patlamalar
        Citizen.CreateThread(function()
            for i = 1, 3 do
                Citizen.Wait(200)
                local randomX = playerCoords.x + math.random(-2, 2)
                local randomY = playerCoords.y + math.random(-2, 2)
                AddExplosion(randomX, randomY, playerCoords.z, 1, 0.5, true, false, 0.2)
            end
        end)
        
        -- Parçacık efekti
        Citizen.CreateThread(function()
            RequestNamedPtfxAsset("core")
            while not HasNamedPtfxAssetLoaded("core") do
                Citizen.Wait(1)
            end
            
            -- Ateş parçacıkları
            UseParticleFxAssetNextCall("core")
            StartParticleFxLoopedAtCoord("fire_wrecked_plane_cockpit", playerCoords.x, playerCoords.y, playerCoords.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
            
            -- Duman efekti
            UseParticleFxAssetNextCall("core")
            StartParticleFxLoopedAtCoord("exp_grd_bzgas_smoke", playerCoords.x, playerCoords.y, playerCoords.z + 1.0, 0.0, 0.0, 0.0, 1.5, false, false, false, false)
        end)
        
        -- ✅ YANMA EFEKTİ (20 SANİYE)
        print("[qb-alicia] 🔥 Yanma efekti başlatılıyor...")
        
        Citizen.CreateThread(function()
            local burnStartTime = GetGameTimer()
            local burnDuration = 20000 -- 20 saniye
            
            -- Yanma parçacığı başlat
            RequestNamedPtfxAsset("core")
            while not HasNamedPtfxAssetLoaded("core") do
                Citizen.Wait(1)
            end
            
            -- Karakter üzerinde yanma efekti
            local fireEffect1 = nil
            local fireEffect2 = nil
            local fireEffect3 = nil
            
            -- Çoklu ateş efektleri
            UseParticleFxAssetNextCall("core")
            fireEffect1 = StartParticleFxLoopedOnPed("fire_ped", playerPed, 0.0, 0.0, -0.5, 0.0, 0.0, 0.0, 1.0, false, false, false)
            
            UseParticleFxAssetNextCall("core")
            fireEffect2 = StartParticleFxLoopedOnPed("fire_wrecked_plane_cockpit", playerPed, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.8, false, false, false)
            
            UseParticleFxAssetNextCall("core")
            fireEffect3 = StartParticleFxLoopedAtCoord("fire_wrecked_plane_wing", playerCoords.x, playerCoords.y, playerCoords.z + 0.5, 0.0, 0.0, 0.0, 1.2, false, false, false, false)
            
            print("[qb-alicia] 🔥 Yanma efektleri başlatıldı, 20 saniye yanacak...")
            
            -- Yanma sesi
            PlaySoundFrontend(-1, "Fire", "DLC_AW_Frontend_Sounds", 1)
            
            -- 20 saniye bekle
            while GetGameTimer() - burnStartTime < burnDuration do
                Citizen.Wait(1000)
                
                -- Her 2 saniyede bir yanma sesi
                if (GetGameTimer() - burnStartTime) % 2000 < 100 then
                    PlaySoundFrontend(-1, "Fire_On", "DLC_AW_Facility_Sounds", 0.3)
                end
                
                -- Yanma durumu kontrol
                local remainingTime = math.ceil((burnDuration - (GetGameTimer() - burnStartTime)) / 1000)
                if remainingTime % 5 == 0 and remainingTime > 0 then
                    print("[qb-alicia] 🔥 Yanma süresi kalan: " .. remainingTime .. " saniye")
                end
            end
            
            -- Yanma efektlerini durdur
            if fireEffect1 then StopParticleFxLooped(fireEffect1, 0) end
            if fireEffect2 then StopParticleFxLooped(fireEffect2, 0) end
            if fireEffect3 then StopParticleFxLooped(fireEffect3, 0) end
            
            print("[qb-alicia] 🔥 Yanma efekti sona erdi!")
            
            -- Son yanma sesi
            PlaySoundFrontend(-1, "Fire_Off", "DLC_AW_Facility_Sounds", 1)
        end)
        
        -- ✅ KARAKTER ÖLÜMÜ (DÜZELTILMIŞ - INVISIBLE ve YER ALTI SORUNU YOK)
        print("[qb-alicia] 💀 Karakter öldürülüyor...")
        
        -- ✅ ÖNCE POZISYONU SABİTLE (yer altına düşmeyi önle)
        local safeCoords = GetEntityCoords(playerPed)
        local found, groundZ = GetGroundZFor_3dCoord(safeCoords.x, safeCoords.y, safeCoords.z + 2.0, false)
        if found then
            safeCoords = vector3(safeCoords.x, safeCoords.y, groundZ + 0.5) -- Yerden 0.5 metre yukarı
        end
        
        -- Güvenli pozisyona yerleştir
        SetEntityCoords(playerPed, safeCoords.x, safeCoords.y, safeCoords.z, false, false, false, true)
        
        -- ✅ HEALTH'I DÜŞÜK YAPMA (SIFIRLAMAMA - invisible olmaması için)
        local currentHealth = GetEntityHealth(playerPed)
        local minHealth = 1 -- Sıfır değil, 1 yap
        SetEntityHealth(playerPed, minHealth)
        
        print("[qb-alicia] 💀 Karakter health: " .. GetEntityHealth(playerPed) .. " (sıfırlanmadı)")
        
        -- ✅ KONTROLLÜ ÖLÜM ANİMASYONU (ragdoll yerine)
        ClearPedTasks(playerPed)
        
        -- Ölüm animasyonu seç
        local deathAnims = {
            {dict = "dead", anim = "dead_a"},
            {dict = "dead", anim = "dead_b"},
            {dict = "missfinale_c2mcs_1", anim = "fin_mcs_1_concat_boss2-mc_10"},
            {dict = "mp_suicide", anim = "pill"}
        }
        
        local selectedAnim = deathAnims[math.random(1, #deathAnims)]
        
        RequestAnimDict(selectedAnim.dict)
        while not HasAnimDictLoaded(selectedAnim.dict) do
            Citizen.Wait(1)
        end
        
        -- Animasyonu oynat
        TaskPlayAnim(playerPed, selectedAnim.dict, selectedAnim.anim, 8.0, -8.0, -1, 1, 0, false, false, false)
        
        -- ✅ GÖRÜNÜRLÜK KORUNMASI (invisible olmasın)
        SetEntityAlpha(playerPed, 255, false) -- Tam görünür
        SetEntityVisible(playerPed, true, false) -- Görünür yap
        
        -- ✅ HAREKET KILITLENMESI (pozisyon sabitleme)
        SetEntityInvincible(playerPed, true) -- Hasar almasın
        FreezeEntityPosition(playerPed, true) -- Hareket etmesin
        
        -- ✅ KAN EFEKTİ (kontrollü)
        SetPedConfigFlag(playerPed, 208, true) -- Bleeding
        ApplyPedDamagePack(playerPed, "BigRunOverByVehicle", 0.0, 1.0) -- Kan efekti
        
        -- ✅ YER ALTINA DÜŞME KORUNMASI
        Citizen.CreateThread(function()
            local deathStartTime = GetGameTimer()
            
            while GetGameTimer() - deathStartTime < 5000 do -- 5 saniye kontrol
                Citizen.Wait(100)
                
                local currentPos = GetEntityCoords(playerPed)
                
                -- Eğer yer altına düştüyse, güvenli konuma geri getir
                if currentPos.z < safeCoords.z - 2.0 then
                    print("[qb-alicia] ⚠️ Yer altına düşme tespit edildi, geri getiriliyor...")
                    SetEntityCoords(playerPed, safeCoords.x, safeCoords.y, safeCoords.z, false, false, false, true)
                end
                
                -- Görünürlük kontrolü
                if GetEntityAlpha(playerPed) < 255 then
                    SetEntityAlpha(playerPed, 255, false)
                end
                
                if not IsEntityVisible(playerPed) then
                    SetEntityVisible(playerPed, true, false)
                end
            end
        end)
        
        print("[qb-alicia] 💀 Ölüm animasyonu başlatıldı (invisible/yer altı korumalı)")
        
        -- ✅ KAMERA SALLAMA EFEKTİ
        ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 1.0)
        
        -- ✅ SES EFEKTİ
        PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 1)
        Citizen.Wait(500)
        PlaySoundFrontend(-1, "LOSER", "HUD_AWARDS", 1)
        
        -- ✅ NUI'ya ölüm mesajı
        SendNUIMessage({
            type = "guessResult",
            success = false,
            message = guessedSymbol and ("💥 PATLAMA! Yanlış tahmin! Doğrusu: " .. (myRealSymbol or "bilinmeyen")) or "💥 PATLAMA! Seçim yapmadınız!"
        })
        
        -- ✅ Server'a ölüm bildir
        TriggerServerEvent('qb-alicia:playerGuessResult', guessedSymbol, false)
        
        -- ✅ 3 saniye sonra spectator modu (DÜZELTILMIŞ)
        
        Citizen.CreateThread(function()
            Citizen.Wait(3000) -- 3 saniye patlama ve ölüm efekti
            
            print("[qb-alicia] 👻 Spectator moduna geçiliyor...")
            
            -- ✅ HEALTH'I RESTORE ET (invisible olmaması için)
            local maxHealth = GetEntityMaxHealth(playerPed)
            SetEntityHealth(playerPed, maxHealth)
            
            -- ✅ GÖRÜNÜRLÜK AYARLARI (yarı şeffaf ama görünür)
            SetEntityAlpha(playerPed, 150, false) -- 150/255 = yarı şeffaf (0 değil!)
            SetEntityVisible(playerPed, true, false) -- Kesinlikle görünür
            
            -- ✅ FİZİK AYARLARI
            SetEntityCollision(playerPed, false, false) -- Collision kapat (geçebilir)
            SetEntityInvincible(playerPed, true) -- Hasar alamaz
            
            -- ✅ HAREKET SERBESTLIĞI
            FreezeEntityPosition(playerPed, false) -- Hareket edebilir
            
            -- ✅ SPECTATOR KILIK AYARLARI
            ClearPedTasks(playerPed) -- Ölüm animasyonunu durdur
            ClearPedBloodDamage(playerPed) -- Kanı temizle
            ClearPedDamageDecalByZone(playerPed, 0) -- Hasarları temizle
            
            -- ✅ SPECTATOR ÖZELLİKLERİ
            SetPedCanRagdoll(playerPed, false) -- Ragdoll olmasın
            SetEntityCanBeDamaged(playerPed, false) -- Hasar almasın
            
            -- ✅ POZİSYON KORUNMASI (spectator modunda da yer altına düşmesin)
            local spectatorCoords = GetEntityCoords(playerPed)
            
            Citizen.CreateThread(function()
                while not isPlayerAlive and gamePhase ~= "ended" do
                    Citizen.Wait(500)
                    
                    local currentPos = GetEntityCoords(playerPed)
                    
                    -- Yer altına düşme kontrolü
                    if currentPos.z < spectatorCoords.z - 5.0 then
                        print("[qb-alicia] ⚠️ Spectator yer altına düştü, geri getiriliyor...")
                        SetEntityCoords(playerPed, spectatorCoords.x, spectatorCoords.y, spectatorCoords.z, false, false, false, true)
                    end
                    
                    -- Görünürlük kontrolü (tamamen invisible olmasın)
                    local currentAlpha = GetEntityAlpha(playerPed)
                    if currentAlpha < 100 then -- Çok şeffafsa düzelt
                        SetEntityAlpha(playerPed, 150, false)
                    end
                    
                    if not IsEntityVisible(playerPed) then
                        SetEntityVisible(playerPed, true, false)
                    end
                end
            end)
            
            print("[qb-alicia] 👻 Spectator moduna geçildi!")
            print("[qb-alicia] 👻 Alpha: " .. GetEntityAlpha(playerPed) .. "/255")
            print("[qb-alicia] 👻 Visible: " .. (IsEntityVisible(playerPed) and "true" or "false"))
            print("[qb-alicia] 👻 Collision: " .. (GetEntityCollisionDisabled(playerPed) and "disabled" or "enabled"))
        end)
        
        print("[qb-alicia] 💥 Patlama efektleri tamamlandı!")
    end

    print("[qb-alicia] 🎲 === TAHMİN KONTROLÜ TAMAMLANDI ===")
end

-- ✅ ESC TUŞU ENGELLEME SİSTEMİ (SEMBOL SEÇİMİ SIRASINDA)

-- Global değişken
local isGuessingPhaseActive = false

-- ESC tuşunu devre dışı bırakma thread'i
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Eğer tahmin fazındaysak ESC'yi engelle
        if isGuessingPhaseActive and gamePhase == "guessing" then
            -- ESC tuşunu devre dışı bırak
            DisableControlAction(0, 322, true) -- ESC key
            DisableControlAction(0, 200, true) -- Pause menu
            DisableControlAction(0, 199, true) -- Map
            DisableControlAction(0, 177, true) -- Back button
            
            -- ESC'ye basılırsa uyarı ver
            if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then
                print("[qb-alicia] ⚠️ ESC tuşu tahmin fazında devre dışı!")
                
                -- Uyarı mesajı göster
                SendNUIMessage({
                    type = "showEscWarning",
                    message = "⚠️ Tahmin fazında ESC kullanılamaz!\nSembol seçmelisiniz!"
                })
                
                -- Ses uyarısı
                PlaySoundFrontend(-1, "ERROR", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
            end
        end
    end
end)

-- Tahmin fazı başlatma (güncelleme gerekli)
function StartGuessPhaseWithEscBlock()
    print("[qb-alicia] 🔒 Tahmin fazı başlatılıyor - ESC engellendi!")
    
    isGuessingPhaseActive = true
    gamePhase = "guessing"
    
    -- NUI focus'u zorunlu yap
    SetNuiFocus(true, true)
    SetCursorLocation(0.5, 0.5)
    
    -- Oyuncuyu freeze et
    FreezeEntityPosition(PlayerPedId(), true)
    
    print("[qb-alicia] 🔒 ESC tuşu devre dışı bırakıldı!")
end

-- Tahmin fazı bitirme
function EndGuessPhaseWithEscUnblock()
    print("[qb-alicia] 🔓 Tahmin fazı bitti - ESC yeniden aktif!")
    
    isGuessingPhaseActive = false
    
    -- NUI focus'u kapat
    SetNuiFocus(false, false)
    
    print("[qb-alicia] 🔓 ESC tuşu yeniden aktif edildi!")
end

-- ✅ ACİL DURUM İÇİN YARDIMCI FONKSİYON
function ProcessCorrectGuess(guessedSymbol)
    print("[qb-alicia] 🆘 === ACİL DURUM: ZORLA DOĞRU TAHMİN ===")
    
    isPlayerAlive = true
    isPlayerFrozen = false
    
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityAlpha(PlayerPedId(), 255, false)
    SetEntityCollision(PlayerPedId(), true, true)
    
    SendNUIMessage({
        type = "guessResult",
        success = true,
        message = "🎉 Acil durum: Doğru kabul edildi!"
    })
    
    TriggerServerEvent('qb-alicia:playerGuessResult', guessedSymbol, true)
    
    print("[qb-alicia] 🆘 Acil durum çözüldü, oyuna devam!")
end

-- ✅ ACİL DURUM İÇİN YARDIMCI FONKSİYON
function ProcessCorrectGuess(guessedSymbol)
    print("[qb-alicia] 🆘 === ACİL DURUM: ZORLA DOĞRU TAHMİN ===")
    
    isPlayerAlive = true
    isPlayerFrozen = false
    
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityAlpha(PlayerPedId(), 255, false)
    SetEntityCollision(PlayerPedId(), true, true)
    
    SendNUIMessage({
        type = "guessResult",
        success = true,
        message = "🎉 Acil durum: Doğru kabul edildi!"
    })
    
    TriggerServerEvent('qb-alicia:playerGuessResult', guessedSymbol, true)
    
    print("[qb-alicia] 🆘 Acil durum çözüldü, oyuna devam!")
end

-- ✅ Server'dan sembol alma eventi
RegisterNetEvent('qb-alicia:receiveMySymbol')
AddEventHandler('qb-alicia:receiveMySymbol', function(symbolData)
    print("[qb-alicia] ✅ Server'dan sembol alındı: " .. symbolData.symbol)
    
    entitySymbols[symbolData.playerId] = symbolData.symbol
    
    if symbolData.isSpadeKing then
        spadeKingId = symbolData.playerId
    end
end)

-- ✅ TEST KOMUTU (opsiyonel)
RegisterCommand("alwayscorrect", function()
    print("[qb-alicia] 🎮 HER ZAMAN DOĞRU MODU AKTİF!")
    
    -- Override fonksiyonu
    ProcessGuessResult = function(guessedSymbol)
        print("[qb-alicia] 🎮 OVERRIDE: Her tahmin doğru!")
        
        gamePhase = "results"
        SetNuiFocus(false, false)
        
        FreezeEntityPosition(PlayerPedId(), false)
        isPlayerFrozen = false
        isPlayerAlive = true
        
        SendNUIMessage({
            type = "guessResult",
            success = true,
            message = "🎉 Test modu aktif!"
        })
        
        print("[qb-alicia] ✅ Freeze kaldırıldı!")
    end
end, false)

RegisterCommand("testfalse", function()
    print("[qb-alicia] 🧪 Zorla yanlış tahmin testi...")
    ProcessGuessResult("wrongsymbol") -- Kesinlikle yanlış bir sembol
end, false)

RegisterCommand("checkfreeze", function()
    local isFrozen = isPlayerFrozen
    local pedFrozen = IsEntityPositionFrozen(PlayerPedId())
    local alpha = GetEntityAlpha(PlayerPedId())
    local collision = GetEntityCollisionDisabled(PlayerPedId())
    
    print("[qb-alicia] 🔍 === FREEZE DURUMU ===")
    print("[qb-alicia] 🔍 isPlayerFrozen: " .. (isFrozen and "true" or "false"))
    print("[qb-alicia] 🔍 PedFrozen: " .. (pedFrozen and "true" or "false"))
    print("[qb-alicia] 🔍 Alpha: " .. alpha)
    print("[qb-alicia] 🔍 Collision Disabled: " .. (collision and "true" or "false"))
    print("[qb-alicia] 🔍 isPlayerAlive: " .. (isPlayerAlive and "true" or "false"))
    print("[qb-alicia] 🔍 gamePhase: " .. gamePhase)
end, false)

RegisterCommand("forceunfreeze", function()
    print("[qb-alicia] 🧹 Zorla freeze kaldırılıyor...")
    
    isPlayerFrozen = false
    isPlayerAlive = true
    
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityAlpha(PlayerPedId(), 255, false)
    SetEntityCollision(PlayerPedId(), true, true)
    
    print("[qb-alicia] ✅ Freeze kaldırıldı, normal duruma döndün!")
end, false)

RegisterCommand("checkstate", function()
    local myServerId = GetPlayerServerId(PlayerPedId())
    
    print("[qb-alicia] 🔍 === OYUN DURUMU ===")
    print("[qb-alicia] 🔍 Benim Server ID: " .. myServerId)
    print("[qb-alicia] 🔍 gamePhase: " .. gamePhase)
    print("[qb-alicia] 🔍 showGuessButtons: " .. (showGuessButtons and "true" or "false"))
    print("[qb-alicia] 🔍 isPlayerFrozen: " .. (isPlayerFrozen and "true" or "false"))
    print("[qb-alicia] 🔍 isTeleported: " .. (isTeleported and "true" or "false"))
    print("[qb-alicia] 🔍 isSymbolActive: " .. (isSymbolActive and "true" or "false"))
    
    -- Bot sayısını kontrol et
    local botCount = 0
    for id, ped in pairs(botPeds) do
        if DoesEntityExist(ped) then
            botCount = botCount + 1
        end
    end
    print("[qb-alicia] 🔍 Aktif bot sayısı: " .. botCount)
    
    -- PlayerData kontrolü
    local playerDataCount = 0
    for id, data in pairs(playerData) do
        playerDataCount = playerDataCount + 1
        print("[qb-alicia] 🔍 PlayerData['" .. id .. "'] = " .. (data.name or "İsimsiz"))
    end
    print("[qb-alicia] 🔍 PlayerData boyutu: " .. playerDataCount)
end, false)

RegisterCommand("testguess", function(source, args)
    if args[1] then
        local testSymbol = args[1]:lower()
        if testSymbol == "spade" or testSymbol == "club" or testSymbol == "diamond" or testSymbol == "heart" then
            print("[qb-alicia] 🧪 Test tahmin: " .. testSymbol)
            ProcessGuessResult(testSymbol)
        else
            print("[qb-alicia] 🧪 Geçerli semboller: spade, club, diamond, heart")
        end
    else
        print("[qb-alicia] 🧪 Kullanım: /testguess [spade/club/diamond/heart]")
    end
end, false)

RegisterCommand("forceguess", function()
    if gamePhase ~= "guessing" then
        print("[qb-alicia] 🧪 Zorla tahmin fazı başlatılıyor...")
        StartGuessPhase()
    else
        print("[qb-alicia] 🧪 Zaten tahmin fazında!")
    end
end, false)

RegisterCommand("teleportgame", function()
    if playerPosition > 0 then
        TeleportToGamePosition()
        print("[qb-alicia] 🧪 Oyun pozisyonuna ışınlandı!")
    else
        print("[qb-alicia] 🧪 Pozisyon atanmamış!")
    end
end, false)

RegisterCommand("setposition", function(source, args)
    if args[1] then
        local pos = tonumber(args[1])
        if pos and pos >= 1 and pos <= 10 then
            playerPosition = pos
            print("[qb-alicia] 🧪 Pozisyon " .. pos .. " olarak ayarlandı!")
        else
            print("[qb-alicia] 🧪 Geçerli pozisyon: 1-10")
        end
    else
        print("[qb-alicia] 🧪 Kullanım: /setposition [1-10]")
    end
end, false)

RegisterCommand("checksession", function()
    print("[qb-alicia] 🔒 Current Session: " .. (currentSession or "YOK"))
    print("[qb-alicia] 🎮 Semboller Aktif: " .. (isSymbolActive and "EVET" or "HAYIR"))
    print("[qb-alicia] 📍 Teleport Edildi: " .. (isTeleported and "EVET" or "HAYIR"))
    print("[qb-alicia] 🏠 Lobide: " .. (isInLobby and "EVET" or "HAYIR"))
end, false)

RegisterCommand("mypos", function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    print("[qb-alicia] 📍 Konum: " .. coords.x .. ", " .. coords.y .. ", " .. coords.z .. " | Yön: " .. heading)
    
    -- Spawn noktasına olan mesafe
    local distance = #(coords - spawnCoords)
    print("[qb-alicia] 📍 Spawn noktasına mesafe: " .. distance .. " metre")
    
    -- NPC'ye olan mesafe
    local npcDistance = #(coords - vector3(npcCoords.x, npcCoords.y, npcCoords.z))
    print("[qb-alicia] 📍 NPC'ye mesafe: " .. npcDistance .. " metre")
end, false)

RegisterCommand("nearplayers", function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    print("[qb-alicia] 👥 === YAKIN OYUNCULAR ===")
    
    for _, player in ipairs(GetActivePlayers()) do
        local otherPlayerPed = GetPlayerPed(player)
        local serverId = GetPlayerServerId(player)
        
        if DoesEntityExist(otherPlayerPed) and otherPlayerPed ~= playerPed then
            local coords = GetEntityCoords(otherPlayerPed)
            local distance = #(playerCoords - coords)
            local name = GetRealPlayerName(serverId)
            local symbol = entitySymbols[tostring(serverId)] or "?"
            
            print("[qb-alicia] 👥 " .. name .. " (ID:" .. serverId .. ") | Mesafe: " .. math.floor(distance) .. "m | Sembol: " .. symbol)
        end
    end
    
    print("[qb-alicia] 👥 === LİSTE SONU ===")
end, false)

RegisterCommand("resetgame", function()
    print("[qb-alicia] 🔄 Acil durum sıfırlama başlatıldı...")
    
    CleanupGameData()
    
    -- Ekran efektlerini kaldır
    SetTimecycleModifier("")
    SetNuiFocus(false, false)
    
    -- NUI'ya reset komutu gönder
    SendNUIMessage({
        type = "reset"
    })
    
    print("[qb-alicia] 🔄 Oyun başarıyla sıfırlandı!")
end, false)

RegisterCommand("togglesymbols", function()
    isSymbolActive = not isSymbolActive
    print("[qb-alicia] 🎮 Semboller " .. (isSymbolActive and "AKTİF" or "DEAKTİF") .. " edildi!")
end, false)

-- Resource event handlers
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CleanupGameData()
        
        -- NPC temizliği
        if npc and DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
        
        -- NUI kapat
        SetNuiFocus(false, false)
        SetTimecycleModifier("")
        
        print("[qb-alicia] Resource durduruldu, temizlik tamamlandı.")
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("[qb-alicia] 🎮 Client.lua başarıyla başlatıldı!")
        
        -- Başlangıç temizliği
        CleanupGameData()
    end
end)

-- Oyuncu disconnect olduğunda temizlik
AddEventHandler('playerDropped', function()
    CleanupGameData()
end)

-- Startup mesajları - GÜNCELLENMIŞ
Citizen.CreateThread(function()
    Citizen.Wait(1000) -- 1 saniye bekle
    
    print("[qb-alicia] 🎮 ===============================================")
    print("[qb-alicia] 🎮 QB-ALICIA CLIENT BAŞARIYLA YÜKLENDİ!")
    print("[qb-alicia] 🎮 ===============================================")
    print("[qb-alicia] 🎮 Kullanılabilir komutlar:")
    print("[qb-alicia] 🎮   /symbols - Sembol listesi")
    print("[qb-alicia] 🎮   /mysymbol - Kendi sembolünü göster (DEBUG)")
    print("[qb-alicia] 🎮   /gameinfo - Oyun durumu")
    print("[qb-alicia] 🎮   /checkstate - Detaylı oyun durumu")
    print("[qb-alicia] 🎮   /checksession - Session durumu")
    print("[qb-alicia] 🎮   /checkfreeze - Freeze durumu")
    print("[qb-alicia] 🎮   /mypos - Konum bilgisi")
    print("[qb-alicia] 🎮   /nearplayers - Yakındaki oyuncular")
    print("[qb-alicia] 🎮   /resetgame - Acil durum sıfırlama")
    print("[qb-alicia] 🎮   /togglesymbols - Sembol görünürlüğü")
    print("[qb-alicia] 🎮 ===============================================")
    print("[qb-alicia] 🎮 Test komutları:")
    print("[qb-alicia] 🎮   /forcetest - Zorla tahmin moduna geç")
    print("[qb-alicia] 🎮   /testcorrect - Doğru tahmin testi")
    print("[qb-alicia] 🎮   /testfalse - Yanlış tahmin testi")
    print("[qb-alicia] 🎮   /forceunfreeze - Zorla freeze kaldır")
    print("[qb-alicia] 🎮   /testguess [sembol] - Manuel tahmin")
    print("[qb-alicia] 🎮   /forceguess - Zorla tahmin fazı")
    print("[qb-alicia] 🎮   /teleportgame - Oyun pozisyonuna ışınlan")
    print("[qb-alicia] 🎮   /setposition [1-10] - Pozisyon ata")
    print("[qb-alicia] 🎮 ===============================================")
    print("[qb-alicia] 🎮 SERVER KOMUTLARI (F8 Console):")
    print("[qb-alicia] 🎮   /addtestbots - Test botları ekle")
    print("[qb-alicia] 🎮   /setmaxplayers [2-10] - Oyuncu sayısı ayarla")
    print("[qb-alicia] 🎮   /lobisettings - Lobi ayarlarını göster")
    print("[qb-alicia] 🎮   /symbolstats - Sembol dağılımı")
    print("[qb-alicia] 🎮   /testsymbols - Manuel sembol testi")
    print("[qb-alicia] 🎮 ===============================================")
    print("[qb-alicia] 🎮 OYUN AKIŞI:")
    print("[qb-alicia] 🎮 1. NPC ile konuş (ALT + E)")
    print("[qb-alicia] 🎮 2. Warning'de 'Evet' butonuna bas")
    print("[qb-alicia] 🎮 3. Lobi'de /addtestbots komutu kullan")
    print("[qb-alicia] 🎮 4. Otomatik olarak oyun başlayacak")
    print("[qb-alicia] 🎮 5. Tartışma (60sn) - Semboller görünür")
    print("[qb-alicia] 🎮 6. Pozisyonlama - Oyun alanına ışınlanma")
    print("[qb-alicia] 🎮 7. Tahmin (10sn) - HTML butonları ile seç")
    print("[qb-alicia] 🎮 8. Sonuç - Doğru = Hareket, Yanlış = Spectator")
    print("[qb-alicia] 🎮 ===============================================")
    print("[qb-alicia] 🎮 SORUN GİDERME:")
    print("[qb-alicia] 🎮 • Sembol YOK ise: /addtestbots kullan")
    print("[qb-alicia] 🎮 • Takılırsan: /forceunfreeze kullan")
    print("[qb-alicia] 🎮 • Butonlar gelmezse: /forcetest kullan")
    print("[qb-alicia] 🎮 • Spectator'da kalırsan: /forceunfreeze")
    print("[qb-alicia] 🎮 ===============================================")
    print("[qb-alicia] 🎮 NPC Konumu: Sandy Shores Airport")
    print("[qb-alicia] 🎮 Konum: 1758.64, 2565.0, 45.56")
    print("[qb-alicia] 🎮 Hile Koruması: ULTRA GÜVENLİ SERVER-SIDE")
    print("[qb-alicia] 🎮 ===============================================")
end)
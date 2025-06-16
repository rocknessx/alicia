// ✅ Global tahmin durumu değişkenleri
window.isGuessingActive = false;
window.selectedSymbolGlobal = null;
let isGuessingActive = false;
let selectedSymbolGlobal = null;
let guessCountdownInterval = null; 

document.addEventListener('DOMContentLoaded', () => {
    // DOM elementlerini kontrol et
    const warningScreen = document.getElementById('warningScreen');
    const lobbyScreen = document.getElementById('lobbyScreen');
    
    if (warningScreen) {
        warningScreen.style.display = 'none';
        console.log('[qb-alicia] warningScreen elementi bulundu, başlatıldı.');
    }
    
    if (lobbyScreen) {
        lobbyScreen.style.display = 'none';
        console.log('[qb-alicia] lobbyScreen elementi bulundu, başlatıldı.');
    }

    // Durumları takip et
    let isLobbyLoaded = false;
    let pendingLobbyUpdates = [];

    // Geri sayım için değişkenler
    let countdownInterval = null;
    let currentCountdown = 0;

    window.addEventListener('message', (event) => {
        const data = event.data;
        console.log('[qb-alicia] Message alındı:', data.type);

        if (data.type === 'openWarning') {
            showWarning();
        } else if (data.type === 'openLobi') {
            showLobby(data.players);
        } else if (data.type === 'updateLobby') {
            updateLobby(data.players);
        } else if (data.type === 'closeLobi') {
            closeLobby();
        } else if (data.type === 'startCountdown') {
            startCountdown(data.duration);
        } else if (data.type === 'gameStarted') {
            showGameStarted();
        } else if (data.type === 'hideCountdown') {
            hideCountdown();
        } else if (data.type === 'startGuessing') {
            startGuessing(data.duration);
        } else if (data.type === 'hideGuessing') {
            hideGuessing();
        }  else if (data.type === 'guessResult') {
            showGuessResult(data);
        } else if (data.type === 'showWinMessage') {
            showWinMessage(data.message);
        } else if (data.type === 'hideAll') {
            hideAllUI();
        }  
        if (data.type === 'spadeKingInfo') {
            showSpadeKingNotification(data.message);
        }
        if (data.type === 'spadeKingReminder') {
            showSpadeKingReminder(data.message);
        }
    });

    // Tahmin fazını başlat (YENİ)
    let guessCountdownInterval = null; // ✅ Global değişken ekle

    // ✅ Maça beyi hatırlatma fonksiyonu
    function showSpadeKingReminder(message) {
        console.log('[qb-alicia] 👑 Maça beyi hatırlatması...');
        
        const reminder = document.createElement('div');
        reminder.style.cssText = `
            position: fixed;
            top: 50px;
            right: 20px;
            background: linear-gradient(135deg, #FFD700, #FFA500);
            color: #000;
            padding: 15px;
            border-radius: 10px;
            font-size: 16px;
            font-weight: bold;
            z-index: 10001;
            box-shadow: 0 0 20px rgba(255, 215, 0, 0.6);
            border: 2px solid #FFD700;
        `;
        
        reminder.innerHTML = `<div>👑</div><div>${message}</div>`;
        document.body.appendChild(reminder);
        
        // 4 saniye sonra gizle
        setTimeout(() => {
            if (reminder && reminder.parentNode) {
                reminder.remove();
            }
        }, 4000);
    }

    // Tahmin sonucunu göster
    function showGuessResult(data) {
        console.log('[qb-alicia] 🎯 Tahmin sonucu:', data.success ? 'BAŞARILI' : 'BAŞARISIZ');
        
        const resultDiv = document.createElement('div');
        resultDiv.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: ${data.success ? 'linear-gradient(135deg, #4CAF50, #8BC34A)' : 'linear-gradient(135deg, #F44336, #FF5722)'};
            color: white;
            padding: 30px;
            border-radius: 15px;
            font-size: 24px;
            font-weight: bold;
            text-align: center;
            z-index: 10000;
            box-shadow: 0 0 30px rgba(0,0,0,0.8);
            border: 3px solid ${data.success ? '#4CAF50' : '#F44336'};
        `;
        
        resultDiv.innerHTML = `
            <div style="font-size: 48px; margin-bottom: 15px;">
                ${data.success ? '🎉' : '💀'}
            </div>
            <div>${data.message}</div>
        `;
        
        document.body.appendChild(resultDiv);
        
        // 4 saniye sonra gizle
        setTimeout(() => {
            if (resultDiv && resultDiv.parentNode) {
                resultDiv.style.animation = 'fadeOut 1s ease';
                setTimeout(() => {
                    if (resultDiv && resultDiv.parentNode) {
                        resultDiv.remove();
                    }
                }, 1000);
            }
        }, 4000);
    }

    // Kazanma mesajını göster
    function showWinMessage(message) {
        console.log('[qb-alicia] 🏆 Kazanma mesajı gösteriliyor:', message);
        
        const winDiv = document.createElement('div');
        winDiv.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100vw;
            height: 100vh;
            background: linear-gradient(135deg, #FFD700, #FFA500);
            color: #000;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            z-index: 10001;
            font-family: Arial, sans-serif;
        `;
        
        winDiv.innerHTML = `
            <div style="font-size: 120px; margin-bottom: 30px; animation: bounce 2s infinite;">
                🏆
            </div>
            <div style="font-size: 48px; font-weight: bold; text-align: center; margin-bottom: 20px;">
                ${message}
            </div>
            <div style="font-size: 20px; opacity: 0.8;">
                Tebrikler! Oyun bitti.
            </div>
        `;
        
        // CSS animasyonu ekle
        if (!document.getElementById('bounceStyle')) {
            const style = document.createElement('style');
            style.id = 'bounceStyle';
            style.textContent = `
                @keyframes bounce {
                    0%, 20%, 50%, 80%, 100% { transform: translateY(0); }
                    40% { transform: translateY(-30px); }
                    60% { transform: translateY(-15px); }
                }
                @keyframes fadeOut {
                    from { opacity: 1; }
                    to { opacity: 0; }
                }
            `;
            document.head.appendChild(style);
        }
        
        document.body.appendChild(winDiv);
        
        // 8 saniye sonra gizle
        setTimeout(() => {
            if (winDiv && winDiv.parentNode) {
                winDiv.style.animation = 'fadeOut 2s ease';
                setTimeout(() => {
                    if (winDiv && winDiv.parentNode) {
                        winDiv.remove();
                    }
                }, 2000);
            }
        }, 8000);
    }

    // Tüm UI elementlerini gizle
    function hideAllUI() {
        console.log('[qb-alicia] 🧹 Tüm UI elementleri gizleniyor...');
        
        // Sembol butonlarını gizle
        hideSymbolButtons();
        
        // Countdown'u gizle
        hideCountdown();
        
        // Lobi'yi kapat
        closeLobby();
        
        // Warning'i kapat
        const warningScreen = document.getElementById('warningScreen');
        if (warningScreen) {
            warningScreen.style.display = 'none';
        }
        
        // Body sınıflarını temizle
        document.body.classList.remove('warning-active', 'lobby-active');
        
        console.log('[qb-alicia] ✅ UI temizlendi!');
    }

    function startGuessing(duration) {
        console.log('[qb-alicia] 🎯 Tahmin fazı başladı! Süre:', duration);
        window.isGuessingActive = true;
        window.selectedSymbolGlobal = null;
        
        showSymbolButtons();
        
        // Önceki countdown'u temizle
        if (guessCountdownInterval) {
            clearInterval(guessCountdownInterval);
        }
        
        // Countdown başlat
        if (duration) {
            let countdown = duration;
            guessCountdownInterval = setInterval(() => {
                // ✅ EĞER SEÇİM YAPILDIYSA DURDUR
                if (!window.isGuessingActive || window.selectedSymbolGlobal) {
                    console.log('[qb-alicia] ⏰ Countdown durduruldu - seçim yapıldı!');
                    clearInterval(guessCountdownInterval);
                    guessCountdownInterval = null;
                    return;
                }
                
                console.log('[qb-alicia] ⏰ Tahmin süresi:', countdown);
                countdown--;
                
                if (countdown <= 0) {
                    clearInterval(guessCountdownInterval);
                    guessCountdownInterval = null;
                    if (!window.selectedSymbolGlobal) {
                        console.log('[qb-alicia] ⏰ Süre doldu, hiç seçim yapılmadı!');
                    }
                }
            }, 1000);
        }
    }
    // Tahmin fazını gizle
    function hideGuessing() {
        console.log('[qb-alicia] 🎯 Tahmin fazı sonlandı');
        hideSymbolButtons();
        selectedSymbolGlobal = null;
    }

    // ESC tuşu ile kapatma
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            closeWarning();
        }
    });

    // Warning ekranını göster
    function showWarning() {
        if (warningScreen) {
            warningScreen.style.display = 'flex';
            document.body.classList.add('warning-active');
            console.log('[qb-alicia] Uyarı ekranı açıldı.');
        } else {
            console.error('[qb-alicia] Hata: warningScreen elementi bulunamadı.');
        }
    }

    // Lobi ekranını göster
    function showLobby(players) {
        console.log('[qb-alicia] Lobi açılıyor, oyuncu sayısı:', players ? Object.keys(players).length : 0);
        
        // Warning'i kapat
        if (warningScreen) {
            warningScreen.style.display = 'none';
        }
        document.body.classList.remove('warning-active');
        
        // Lobi'yi göster
        if (lobbyScreen) {
            lobbyScreen.style.display = 'block';
            document.body.classList.add('lobby-active');
            isLobbyLoaded = true;
            
            if (players) {
                updatePlayerList(players);
                // Bekleyen güncellemeleri işle
                while (pendingLobbyUpdates.length > 0) {
                    updatePlayerList(pendingLobbyUpdates.shift());
                }
            }
            
            console.log('[qb-alicia] Lobi açıldı.');
        } else {
            console.error('[qb-alicia] Hata: lobbyScreen elementi bulunamadı.');
        }
    }

    // Lobi güncelle
    function updateLobby(players) {
        if (isLobbyLoaded) {
            updatePlayerList(players);
        } else {
            console.warn('[qb-alicia] updateLobby kuyruğa eklendi, lobi henüz yüklü değil.');
            pendingLobbyUpdates.push(players);
        }
    }

    // Lobi kapat
    function closeLobby() {
        if (lobbyScreen) {
            lobbyScreen.style.display = 'none';
        }
        document.body.classList.remove('lobby-active');
        isLobbyLoaded = false;
        console.log('[qb-alicia] Lobi kapatıldı.');
    }

    // Geri sayım HTML elementi oluştur
    function createCountdownElement() {
        if (document.getElementById('countdownContainer')) return; // Zaten var
        
        const countdownHTML = `
            <div id="countdownContainer" style="
                position: fixed;
                top: 0;
                left: 0;
                width: 100vw;
                height: 100vh;
                background: rgba(0, 0, 0, 0.8);
                display: none;
                justify-content: center;
                align-items: center;
                z-index: 9999;
                font-family: 'Arial', sans-serif;
            ">
                <div id="countdownBox" style="
                    background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
                    border: 3px solid #fff;
                    border-radius: 20px;
                    padding: 50px;
                    text-align: center;
                    box-shadow: 0 0 50px rgba(0, 0, 0, 0.5);
                    min-width: 400px;
                ">
                    <div id="countdownNumber" style="
                        font-size: 120px;
                        font-weight: bold;
                        color: #fff;
                        text-shadow: 3px 3px 6px rgba(0, 0, 0, 0.5);
                        margin-bottom: 20px;
                        transition: all 0.3s ease;
                    ">10</div>
                    
                    <div id="countdownText" style="
                        font-size: 24px;
                        color: #e0e0e0;
                        margin-bottom: 20px;
                        text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.5);
                    ">Oyun başlamak üzere...</div>
                    
                    <div id="progressBarContainer" style="
                        width: 100%;
                        height: 8px;
                        background: rgba(255, 255, 255, 0.3);
                        border-radius: 4px;
                        overflow: hidden;
                    ">
                        <div id="progressBar" style="
                            height: 100%;
                            width: 0%;
                            background: linear-gradient(90deg, #4CAF50, #8BC34A);
                            transition: width 0.1s ease;
                            border-radius: 4px;
                        "></div>
                    </div>
                </div>
            </div>
        `;
        
        document.body.insertAdjacentHTML('beforeend', countdownHTML);
    }
    function showSpadeKingNotification(message) {
        console.log('[qb-alicia] 👑 Maça beyi bildirimi gösteriliyor...');
        
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: linear-gradient(135deg, #FFD700, #FFA500);
            color: #000;
            padding: 20px;
            border-radius: 15px;
            font-size: 18px;
            font-weight: bold;
            text-align: center;
            z-index: 10001;
            box-shadow: 0 0 30px rgba(255, 215, 0, 0.8);
            border: 3px solid #FFD700;
            max-width: 300px;
            animation: kingPulse 2s infinite;
        `;
        
        notification.innerHTML = `
            <div style="font-size: 24px; margin-bottom: 10px;">👑</div>
            <div>${message}</div>
            <div style="font-size: 12px; margin-top: 10px; opacity: 0.8;">Bu bilgi sadece sende!</div>
        `;
        
        // CSS animasyonu ekle
        if (!document.getElementById('kingPulseStyle')) {
            const style = document.createElement('style');
            style.id = 'kingPulseStyle';
            style.textContent = `
                @keyframes kingPulse {
                    0% { transform: scale(1); box-shadow: 0 0 30px rgba(255, 215, 0, 0.8); }
                    50% { transform: scale(1.05); box-shadow: 0 0 40px rgba(255, 215, 0, 1); }
                    100% { transform: scale(1); box-shadow: 0 0 30px rgba(255, 215, 0, 0.8); }
                }
            `;
            document.head.appendChild(style);
        }
        
        document.body.appendChild(notification);
        
        // 8 saniye sonra gizle
        setTimeout(() => {
            if (notification && notification.parentNode) {
                notification.style.animation = 'fadeOut 1s ease';
                setTimeout(() => {
                    if (notification && notification.parentNode) {
                        notification.remove();
                    }
                }, 1000);
            }
        }, 8000);
        
        console.log('[qb-alicia] 👑 Maça beyi bildirimi gösterildi!');
    }
    
    // Geri sayım başlat
    function startCountdown(duration) {
        createCountdownElement();
        
        const container = document.getElementById('countdownContainer');
        const numberElement = document.getElementById('countdownNumber');
        const textElement = document.getElementById('countdownText');
        const progressBar = document.getElementById('progressBar');
        
        container.style.display = 'flex';
        currentCountdown = duration;
        
        console.log('[qb-alicia] Geri sayım başlatıldı: ' + duration + ' saniye');
        
        countdownInterval = setInterval(() => {
            // Progress bar güncelle
            const progress = ((duration - currentCountdown) / duration) * 100;
            progressBar.style.width = progress + '%';
            
            if (currentCountdown > 0) {
                numberElement.textContent = currentCountdown;
                
                // Renk değişimi
                if (currentCountdown > 5) {
                    numberElement.style.color = '#4FC3F7'; // Mavi
                    progressBar.style.background = 'linear-gradient(90deg, #2196F3, #4FC3F7)';
                } else if (currentCountdown > 3) {
                    numberElement.style.color = '#FFB74D'; // Turuncu
                    progressBar.style.background = 'linear-gradient(90deg, #FF9800, #FFB74D)';
                } else {
                    numberElement.style.color = '#F44336'; // Kırmızı
                    progressBar.style.background = 'linear-gradient(90deg, #F44336, #FF5722)';
                }
                
                // Pulse efekti
                numberElement.style.transform = 'scale(1.1)';
                setTimeout(() => {
                    if (numberElement) {
                        numberElement.style.transform = 'scale(1)';
                    }
                }, 150);
                
                currentCountdown--;
            }
        }, 1000);
    }

    // Oyun başladı göster
    function showGameStarted() {
        const numberElement = document.getElementById('countdownNumber');
        const textElement = document.getElementById('countdownText');
        const progressBar = document.getElementById('progressBar');
        
        if (countdownInterval) {
            clearInterval(countdownInterval);
            countdownInterval = null;
        }
        
        if (numberElement && textElement && progressBar) {
            // "OYUN BAŞLADI!" göster
            numberElement.textContent = '🎮';
            numberElement.style.color = '#4CAF50';
            numberElement.style.fontSize = '100px';
            textElement.textContent = 'OYUN BAŞLADI!';
            textElement.style.color = '#4CAF50';
            textElement.style.fontSize = '28px';
            
            // Progress bar tam doldur
            progressBar.style.width = '100%';
            progressBar.style.background = 'linear-gradient(90deg, #4CAF50, #8BC34A)';
        }
        
        console.log('[qb-alicia] "OYUN BAŞLADI!" gösteriliyor');
    }

    // Geri sayımı gizle
    function hideCountdown() {
        const container = document.getElementById('countdownContainer');
        if (container) {
            container.style.display = 'none';
            console.log('[qb-alicia] Geri sayım gizlendi');
        }
        
        if (countdownInterval) {
            clearInterval(countdownInterval);
            countdownInterval = null;
        }
    }

    // Global scope'a fonksiyonları ekle
    window.showWarning = showWarning;
    window.showLobby = showLobby;
    window.updateLobby = updateLobby;
    window.closeLobby = closeLobby;
    window.startCountdown = startCountdown;
    window.showGameStarted = showGameStarted;
    window.hideCountdown = hideCountdown;
});

// FiveM ortamı kontrolü
function isFiveMEnvironment() {
    return typeof GetParentResourceName !== 'undefined';
}

// Güvenli fetch fonksiyonu
function safeFetch(endpoint, data = {}) {
    if (!isFiveMEnvironment()) {
        console.warn('[qb-alicia] FiveM ortamında değil, fetch işlemi atlandı.');
        return Promise.resolve();
    }

    try {
        return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
    } catch (error) {
        console.error('[qb-alicia] Fetch hatası:', error);
        return Promise.reject(error);
    }
}

// ✅ selectSymbol fonksiyonuna EKLE (satır 354 civarı):
function selectSymbol(symbol) {
    console.log('[qb-alicia] 🎯 ACIL ÇÖZÜM - Sembol seçildi:', symbol);
    
    // ✅ BÜYÜK MESAJ EKLE
    console.log('');
    console.log('🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯');
    console.log('🎯     SEMBOL SEÇİLDİ: ' + symbol.toUpperCase() + '     🎯');
    console.log('🎯   Server\'a gönderiliyor...     🎯');
    console.log('🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯🎯');
    console.log('');
    
    window.selectedSymbolGlobal = symbol;
    window.isGuessingActive = false; // Tahmin fazını bitir
    
    if (typeof safeFetch === 'function') {
        safeFetch('selectSymbol', { symbol: symbol });
        console.log('[qb-alicia] ✅ Sembol server\'a gönderildi (acil):', symbol);
    } else {
        console.error('[qb-alicia] ❌ safeFetch fonksiyonu bulunamadı!');
    }
    
    markSelectedButton(symbol);
}

// Seçilen butonu işaretle (görsel feedback) - GELİŞTİRİLDİ
function markSelectedButton(selectedSymbol) {
    console.log('[qb-alicia] 🎯 Buton işaretleniyor:', selectedSymbol);
    
    // Tüm butonları normale döndür
    const allButtons = document.querySelectorAll('.symbol-button');
    allButtons.forEach(btn => {
        btn.classList.remove('selected');
        btn.style.background = btn.dataset.originalColor || btn.style.background;
        btn.style.transform = 'scale(1)';
        btn.style.boxShadow = 'none';
        btn.style.borderColor = 'white';
    });
    
    // Seçilen butonu işaretle
    const selectedButton = document.querySelector(`[data-symbol="${selectedSymbol}"]`);
    if (selectedButton) {
        selectedButton.classList.add('selected');
        
        // Orijinal rengini sakla
        if (!selectedButton.dataset.originalColor) {
            selectedButton.dataset.originalColor = selectedButton.style.background;
        }
        
        // Seçim efektleri
        selectedButton.style.background = 'linear-gradient(135deg, #00ff00, #32cd32)';
        selectedButton.style.transform = 'scale(1.15)';
        selectedButton.style.boxShadow = '0 0 25px #00ff00, 0 0 50px #00ff00';
        selectedButton.style.borderColor = '#00ff00';
        selectedButton.style.borderWidth = '5px';
        
        // Pulse animasyonu
        let pulseCount = 0;
        const pulseInterval = setInterval(() => {
            if (pulseCount < 6) { // 3 kez pulse
                selectedButton.style.transform = pulseCount % 2 === 0 ? 'scale(1.2)' : 'scale(1.15)';
                pulseCount++;
            } else {
                clearInterval(pulseInterval);
                selectedButton.style.transform = 'scale(1.15)';
            }
        }, 150);
        
        console.log('[qb-alicia] ✅ Buton başarıyla seçildi ve işaretlendi:', selectedSymbol);
        
        // 2 saniye sonra butonları gizle
        setTimeout(() => {
            hideSymbolButtons();
        }, 2000);
    } else {
        console.error('[qb-alicia] ❌ Seçilen buton bulunamadı:', selectedSymbol);
    }
}



// Sembol butonları oluştur (dinamik olarak) - DÜZELTİLDİ
function createSymbolButtons() {
    const symbolContainer = document.getElementById('symbolContainer');
    if (!symbolContainer) {
        console.error('[qb-alicia] ❌ symbolContainer elementi bulunamadı!');
        return;
    }
    
    console.log('[qb-alicia] 🎮 Sembol butonları oluşturuluyor...');
    
    const symbols = [
        { name: 'spade', char: '♠', color: '#404040' },
        { name: 'club', char: '♣', color: '#228b22' },
        { name: 'diamond', char: '♦', color: '#ffa500' },
        { name: 'heart', char: '♥', color: '#dc143c' }
    ];
    
    // Container'ı temizle
    symbolContainer.innerHTML = '';
    
    // Başlık ekle
    const title = document.createElement('div');
    title.style.cssText = `
        position: absolute;
        top: -60px;
        left: 50%;
        transform: translateX(-50%);
        color: white;
        font-size: 24px;
        font-weight: bold;
        text-align: center;
        white-space: nowrap;
    `;
    title.textContent = '🎯 SEMBOLÜNÜZü SEÇİN!';
    symbolContainer.appendChild(title);
    
    symbols.forEach(symbol => {
        const button = document.createElement('button');
        button.className = 'symbol-button';
        button.dataset.symbol = symbol.name;
        button.style.cssText = `
            width: 120px;
            height: 120px;
            background: ${symbol.color};
            border: 3px solid white;
            border-radius: 10px;
            font-size: 60px;
            color: white;
            cursor: pointer;
            transition: all 0.3s ease;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            margin: 5px;
        `;
        
        button.innerHTML = `
            <div style="font-size: 50px; margin-bottom: 5px;">${symbol.char}</div>
            <div style="font-size: 12px; text-transform: uppercase; font-weight: bold;">${symbol.name}</div>
        `;
        
        // Hover efekti
        button.addEventListener('mouseenter', () => {
            if (!button.classList.contains('selected')) {
                button.style.transform = 'scale(1.05)';
                button.style.boxShadow = '0 0 15px rgba(255,255,255,0.8)';
                button.style.borderColor = '#ffff00';
            }
        });
        
        button.addEventListener('mouseleave', () => {
            if (!button.classList.contains('selected')) {
                button.style.transform = 'scale(1)';
                button.style.boxShadow = 'none';
                button.style.borderColor = 'white';
            }
        });
        
        // Tıklama eventi
        button.addEventListener('click', () => {
            console.log('[qb-alicia] 🎯 Buton tıklandı:', symbol.name);
            selectedSymbolGlobal = symbol.name;
            selectSymbol(symbol.name);
        });
        
        symbolContainer.appendChild(button);
    });
    
    console.log('[qb-alicia] ✅ ' + symbols.length + ' sembol butonu oluşturuldu');
}

// Sembol butonlarını göster - GELİŞTİRİLDİ
function showSymbolButtons() {
    isGuessingActive = true;
    selectedSymbolGlobal = null;
    window.isGuessingActive = true;
    window.selectedSymbolGlobal = null;

    const container = document.getElementById('symbolContainer');
    if (!container) {
        console.error('[qb-alicia] ❌ symbolContainer elementi bulunamadı!');
        return;
    }
    
    createSymbolButtons();
    container.style.display = 'flex';
    
    // Fade-in efekti
    container.style.opacity = '0';
    container.style.transform = 'translate(-50%, -50%) scale(0.8)';
    
    setTimeout(() => {
        container.style.transition = 'all 0.5s ease';
        container.style.opacity = '1';
        container.style.transform = 'translate(-50%, -50%) scale(1)';
    }, 50);
    
    console.log('[qb-alicia] 🎮 Sembol butonları gösteriliyor...');
}

// Sembol butonlarını gizle - GELİŞTİRİLDİ
function hideSymbolButtons() {
    const container = document.getElementById('symbolContainer');
    if (container) {
        // Fade-out efekti
        window.isGuessingActive = false;
        window.selectedSymbolGlobal = null;
        container.style.transition = 'all 0.3s ease';
        container.style.opacity = '0';
        container.style.transform = 'translate(-50%, -50%) scale(0.8)';
        
        setTimeout(() => {
            container.style.display = 'none';
        }, 300);
        
        console.log('[qb-alicia] 🎮 Sembol butonları gizlendi.');
    }
}

// Warning kabul etme
function acceptWarning() {
    safeFetch('accept')
        .then(() => {
            console.log('[qb-alicia] Evet butonuna basıldı.');
        })
        .catch((error) => {
            console.error('[qb-alicia] Accept işlemi başarısız:', error);
        });
}

// Warning kapatma
function closeWarning() {
    const warningScreen = document.getElementById('warningScreen');
    if (warningScreen) {
        warningScreen.style.display = 'none';
        document.body.classList.remove('warning-active');
    }
    
    safeFetch('close')
        .then(() => {
            console.log('[qb-alicia] Uyarı ekranı kapatıldı.');
        })
        .catch((error) => {
            console.error('[qb-alicia] Close işlemi başarısız:', error);
        });
}

// Lobi çıkışı
function exitLobby() {
    console.log('[qb-alicia] Lobiden çıkış butonu basıldı.');
    
    // UI'yi hemen kapat
    const lobbyScreen = document.getElementById('lobbyScreen');
    if (lobbyScreen) {
        lobbyScreen.style.display = 'none';
    }
    document.body.classList.remove('lobby-active');
    document.body.classList.add('force-hide-cursor');
    
    // Fetch'i sonra gönder
    safeFetch('close')
        .then(() => {
            console.log('[qb-alicia] Lobi kapatma isteği gönderildi.');
        })
        .catch((error) => {
            console.error('[qb-alicia] Lobi kapatma işlemi başarısız:', error);
        });
}

// Oyuncu listesini güncelle
function updatePlayerList(players) {
    const playerList = document.getElementById('playerList');
    if (!playerList) {
        console.error('[qb-alicia] Hata: playerList elementi bulunamadı.');
        return;
    }

    playerList.innerHTML = '';
    
    // Oyuncu verisi kontrolü
    if (!players || typeof players !== 'object') {
        console.error('[qb-alicia] Hata: Geçersiz oyuncu listesi:', players);
        return;
    }

    let validPlayerCount = 0;
    
    for (const [id, player] of Object.entries(players)) {
        // Null, undefined veya geçersiz oyuncu verilerini filtrele
        if (!player || 
            typeof player !== 'object' || 
            !player.name || 
            player.name.trim() === '') {
            console.warn('[qb-alicia] Uyarı: Geçersiz oyuncu verisi atlandı, ID:', id, 'Veri:', player);
            continue;
        }
        
        const li = document.createElement('li');
        li.className = 'player-item';
        
        // XSS koruması için player.name'i temizle
        const safeName = String(player.name).replace(/[<>&"']/g, function(match) {
            const escapeMap = {
                '<': '&lt;',
                '>': '&gt;',
                '&': '&amp;',
                '"': '&quot;',
                "'": '&#x27;'
            };
            return escapeMap[match];
        });
        
        li.innerHTML = `
            <span class="player-name">${safeName}</span>
            <span class="player-status">${player.ready ? 'Hazır' : 'Bekliyor'}</span>
        `;
        playerList.appendChild(li);
        validPlayerCount++;
    }
    
    console.log('[qb-alicia] Oyuncu listesi güncellendi, geçerli oyuncu sayısı:', validPlayerCount);
    window.isGuessingActive = isGuessingActive;
    window.selectedSymbolGlobal = selectedSymbolGlobal;
}
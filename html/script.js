// Main JavaScript for NPC AI Voice Interface
class NPCAIInterface {
    constructor() {
        this.isVisible = false;
        this.debug = false;
        this.conversation = [];
        
        this.elements = {
            voiceStatus: document.getElementById('voice-status'),
            statusText: document.getElementById('status-text'),
            conversationDisplay: document.getElementById('conversation-display'),
            conversationContent: document.getElementById('conversation-content'),
            debugInfo: document.getElementById('debug-info'),
            debugContent: document.getElementById('debug-content')
        };
        
        this.bindEvents();
        this.log('NPC AI Interface initialized');
    }
    
    bindEvents() {
        // Listen for messages from FiveM
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            switch (data.type) {
                case 'startSpeechRecognition':
                    this.startSpeechRecognition(data.config);
                    break;
                case 'stopSpeechRecognition':
                    this.stopSpeechRecognition();
                    break;
                case 'playTTS':
                    this.playTTS(data.text, data.voice, data.rate, data.pitch);
                    break;
                case 'showConversation':
                    this.showConversation(data.messages);
                    break;
                case 'hideInterface':
                    this.hideInterface();
                    break;
                case 'showDebug':
                    this.showDebug(data.info);
                    break;
                case 'addMessage':
                    this.addMessage(data.speaker, data.message);
                    break;
            }
        });
    }
    
    log(message) {
        if (this.debug) {
            console.log(`[NPC-AI] ${message}`);
        }
        this.updateDebugInfo(`${new Date().toLocaleTimeString()}: ${message}`);
    }
    
    updateDebugInfo(info) {
        if (this.elements.debugContent) {
            const debugItem = document.createElement('div');
            debugItem.className = 'debug-item';
            debugItem.textContent = info;
            this.elements.debugContent.appendChild(debugItem);
            
            // Keep only last 10 debug messages
            const items = this.elements.debugContent.children;
            if (items.length > 10) {
                this.elements.debugContent.removeChild(items[0]);
            }
        }
    }
    
    showInterface() {
        this.isVisible = true;
        this.elements.conversationDisplay.classList.remove('hidden');
        this.elements.conversationDisplay.classList.add('fade-in');
    }
    
    hideInterface() {
        this.isVisible = false;
        this.elements.voiceStatus.classList.add('hidden');
        this.elements.conversationDisplay.classList.add('hidden');
        this.stopSpeechRecognition();
    }
    
    showDebug(info) {
        this.debug = true;
        this.elements.debugInfo.classList.remove('hidden');
        if (info) {
            this.updateDebugInfo(JSON.stringify(info));
        }
    }
    
    addMessage(speaker, message) {
        this.conversation.push({ speaker, message, timestamp: Date.now() });
        this.renderConversation();
        
        if (!this.isVisible) {
            this.showInterface();
        }
    }
    
    renderConversation() {
        this.elements.conversationContent.innerHTML = '';
        
        this.conversation.forEach(msg => {
            const messageEl = document.createElement('div');
            messageEl.className = `message ${msg.speaker}`;
            
            const contentEl = document.createElement('div');
            contentEl.className = 'message-content';
            contentEl.textContent = msg.message;
            
            const timeEl = document.createElement('div');
            timeEl.className = 'message-time';
            timeEl.textContent = new Date(msg.timestamp).toLocaleTimeString();
            
            messageEl.appendChild(contentEl);
            messageEl.appendChild(timeEl);
            this.elements.conversationContent.appendChild(messageEl);
        });
        
        // Auto-scroll to bottom
        this.elements.conversationDisplay.scrollTop = this.elements.conversationDisplay.scrollHeight;
    }
    
    clearConversation() {
        this.conversation = [];
        this.renderConversation();
    }
    
    startSpeechRecognition(config) {
        this.log('Starting speech recognition with config: ' + JSON.stringify(config));
        this.elements.voiceStatus.classList.remove('hidden');
        this.elements.statusText.textContent = 'Écoute...';
        
        // Delegate to voice.js
        if (window.VoiceHandler) {
            window.VoiceHandler.startSpeechRecognition(config);
        }
    }
    
    stopSpeechRecognition() {
        this.log('Stopping speech recognition');
        this.elements.voiceStatus.classList.add('hidden');
        
        // Delegate to voice.js
        if (window.VoiceHandler) {
            window.VoiceHandler.stopSpeechRecognition();
        }
    }
    
    playTTS(text, voice, rate = 1.0, pitch = 1.0) {
        this.log(`Playing TTS: "${text}" with voice: ${voice}`);
        
        // Delegate to voice.js
        if (window.VoiceHandler) {
            window.VoiceHandler.playTTS(text, voice, rate, pitch);
        }
    }
    
    // Utility methods
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    formatTime(timestamp) {
        return new Date(timestamp).toLocaleTimeString('fr-FR', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
    }
}

// Initialize the interface when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.NPCAIInterface = new NPCAIInterface();
});

// Expose interface to window for external access
window.addMessage = (speaker, message) => {
    if (window.NPCAIInterface) {
        window.NPCAIInterface.addMessage(speaker, message);
    }
};

window.clearConversation = () => {
    if (window.NPCAIInterface) {
        window.NPCAIInterface.clearConversation();
    }
};

window.showDebug = (info) => {
    if (window.NPCAIInterface) {
        window.NPCAIInterface.showDebug(info);
    }
};
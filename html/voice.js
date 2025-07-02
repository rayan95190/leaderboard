// Voice handling for speech recognition and text-to-speech
class VoiceHandler {
    constructor() {
        this.recognition = null;
        this.synthesis = window.speechSynthesis;
        this.isRecognizing = false;
        this.currentUtterance = null;
        
        this.initializeSpeechRecognition();
        this.log('Voice handler initialized');
    }
    
    log(message) {
        console.log(`[Voice] ${message}`);
        if (window.NPCAIInterface) {
            window.NPCAIInterface.updateDebugInfo(`Voice: ${message}`);
        }
    }
    
    initializeSpeechRecognition() {
        // Check for browser support
        if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
            this.log('Speech recognition not supported in this browser');
            this.sendCallback('speechError', { error: 'Speech recognition not supported' });
            return;
        }
        
        // Initialize speech recognition
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        this.recognition = new SpeechRecognition();
        
        // Configure recognition
        this.recognition.continuous = true;
        this.recognition.interimResults = true;
        this.recognition.maxAlternatives = 1;
        
        // Event handlers
        this.recognition.onstart = () => {
            this.log('Speech recognition started');
            this.isRecognizing = true;
        };
        
        this.recognition.onend = () => {
            this.log('Speech recognition ended');
            this.isRecognizing = false;
        };
        
        this.recognition.onerror = (event) => {
            this.log('Speech recognition error: ' + event.error);
            this.sendCallback('speechError', { error: event.error });
            this.isRecognizing = false;
        };
        
        this.recognition.onresult = (event) => {
            this.handleSpeechResult(event);
        };
        
        this.log('Speech recognition initialized');
    }
    
    startSpeechRecognition(config = {}) {
        if (!this.recognition) {
            this.log('Speech recognition not available');
            return;
        }
        
        if (this.isRecognizing) {
            this.log('Speech recognition already running');
            return;
        }
        
        // Apply configuration
        if (config.language) {
            this.recognition.lang = config.language;
        }
        if (config.continuous !== undefined) {
            this.recognition.continuous = config.continuous;
        }
        if (config.interimResults !== undefined) {
            this.recognition.interimResults = config.interimResults;
        }
        
        try {
            this.recognition.start();
            this.log(`Starting speech recognition with language: ${this.recognition.lang}`);
        } catch (error) {
            this.log('Error starting speech recognition: ' + error.message);
            this.sendCallback('speechError', { error: error.message });
        }
    }
    
    stopSpeechRecognition() {
        if (!this.recognition || !this.isRecognizing) {
            return;
        }
        
        try {
            this.recognition.stop();
            this.log('Stopping speech recognition');
        } catch (error) {
            this.log('Error stopping speech recognition: ' + error.message);
        }
    }
    
    handleSpeechResult(event) {
        let finalTranscript = '';
        let interimTranscript = '';
        
        for (let i = event.resultIndex; i < event.results.length; i++) {
            const transcript = event.results[i][0].transcript;
            
            if (event.results[i].isFinal) {
                finalTranscript += transcript;
            } else {
                interimTranscript += transcript;
            }
        }
        
        // Log the transcripts
        if (interimTranscript) {
            this.log('Interim: ' + interimTranscript);
        }
        
        if (finalTranscript) {
            finalTranscript = finalTranscript.trim();
            this.log('Final: ' + finalTranscript);
            
            // Send final result to FiveM
            this.sendCallback('speechResult', { 
                transcript: finalTranscript,
                confidence: event.results[event.resultIndex][0].confidence 
            });
        }
    }
    
    playTTS(text, voice = 'fr-FR-Standard-A', rate = 1.0, pitch = 1.0) {
        if (!this.synthesis) {
            this.log('Speech synthesis not supported');
            this.sendCallback('ttsError', { error: 'TTS not supported' });
            return;
        }
        
        // Stop any current speech
        this.stopTTS();
        
        // Create utterance
        this.currentUtterance = new SpeechSynthesisUtterance(text);
        
        // Configure utterance
        this.currentUtterance.rate = rate;
        this.currentUtterance.pitch = pitch;
        this.currentUtterance.volume = 1.0;
        
        // Try to find the requested voice
        const voices = this.synthesis.getVoices();
        const selectedVoice = voices.find(v => 
            v.name.includes(voice) || 
            v.lang.startsWith(voice.substring(0, 5))
        );
        
        if (selectedVoice) {
            this.currentUtterance.voice = selectedVoice;
            this.log(`Using voice: ${selectedVoice.name} (${selectedVoice.lang})`);
        } else {
            // Fallback to first French voice or default
            const frenchVoice = voices.find(v => v.lang.startsWith('fr'));
            if (frenchVoice) {
                this.currentUtterance.voice = frenchVoice;
                this.log(`Fallback to French voice: ${frenchVoice.name}`);
            } else {
                this.log('Using default voice');
            }
        }
        
        // Event handlers
        this.currentUtterance.onstart = () => {
            this.log('TTS started');
        };
        
        this.currentUtterance.onend = () => {
            this.log('TTS completed');
            this.sendCallback('ttsComplete', {});
            this.currentUtterance = null;
        };
        
        this.currentUtterance.onerror = (event) => {
            this.log('TTS error: ' + event.error);
            this.sendCallback('ttsError', { error: event.error });
            this.currentUtterance = null;
        };
        
        // Speak the text
        try {
            this.synthesis.speak(this.currentUtterance);
            this.log(`Playing TTS: "${text}"`);
        } catch (error) {
            this.log('Error playing TTS: ' + error.message);
            this.sendCallback('ttsError', { error: error.message });
        }
    }
    
    stopTTS() {
        if (this.synthesis && this.synthesis.speaking) {
            this.synthesis.cancel();
            this.log('TTS stopped');
        }
        this.currentUtterance = null;
    }
    
    // Get available voices
    getAvailableVoices() {
        if (!this.synthesis) return [];
        
        const voices = this.synthesis.getVoices();
        return voices.map(voice => ({
            name: voice.name,
            lang: voice.lang,
            gender: voice.name.toLowerCase().includes('female') ? 'female' : 'male'
        }));
    }
    
    // Send callback to FiveM
    sendCallback(type, data) {
        if (window.invokeNative) {
            // Send via FiveM NUI callback
            fetch(`https://npc-ai-voice/${type}`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(data)
            }).catch(error => {
                this.log('Error sending callback: ' + error.message);
            });
        } else {
            this.log(`Callback ${type}: ${JSON.stringify(data)}`);
        }
    }
    
    // Test functions
    testSpeechRecognition() {
        this.log('Testing speech recognition...');
        this.startSpeechRecognition({ 
            language: 'fr-FR',
            continuous: false,
            interimResults: true 
        });
        
        setTimeout(() => {
            this.stopSpeechRecognition();
        }, 5000);
    }
    
    testTTS() {
        this.log('Testing TTS...');
        this.playTTS('Bonjour, ceci est un test de synthèse vocale.', 'fr-FR');
    }
}

// Initialize voice handler when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Wait for voices to be loaded
    if (window.speechSynthesis) {
        if (window.speechSynthesis.getVoices().length === 0) {
            window.speechSynthesis.addEventListener('voiceschanged', () => {
                window.VoiceHandler = new VoiceHandler();
            });
        } else {
            window.VoiceHandler = new VoiceHandler();
        }
    } else {
        console.warn('Speech synthesis not supported');
    }
});

// Expose voice handler for testing
window.testVoice = () => {
    if (window.VoiceHandler) {
        window.VoiceHandler.testTTS();
    }
};

window.testSpeech = () => {
    if (window.VoiceHandler) {
        window.VoiceHandler.testSpeechRecognition();
    }
};

window.getVoices = () => {
    if (window.VoiceHandler) {
        return window.VoiceHandler.getAvailableVoices();
    }
    return [];
};
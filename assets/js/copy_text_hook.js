export const CopyTextHook = {
  mounted() {
    this.handleEvent("copy_text", (payload) => {
      this.copyText(payload.field);
    });
  },

  copyText(field) {
    const meeting = this.el.closest('[data-meeting]');
    let textToCopy = '';
    
    // Get the content based on field type
    switch(field) {
      case 'email':
        textToCopy = meeting.dataset.emailContent || '';
        break;
      case 'linkedin':
        textToCopy = meeting.dataset.linkedinContent || '';
        break;
      case 'facebook':
        textToCopy = meeting.dataset.facebookContent || '';
        break;
      case 'transcript':
        textToCopy = meeting.dataset.transcriptContent || '';
        break;
    }
    
    if (textToCopy && navigator.clipboard) {
      navigator.clipboard.writeText(textToCopy).then(() => {
        console.log('Text copied to clipboard');
      }).catch(err => {
        console.error('Failed to copy text: ', err);
        // Fallback for older browsers
        this.fallbackCopyTextToClipboard(textToCopy);
      });
    } else {
      this.fallbackCopyTextToClipboard(textToCopy);
    }
  },

  fallbackCopyTextToClipboard(text) {
    const textArea = document.createElement("textarea");
    textArea.value = text;
    
    // Avoid scrolling to bottom
    textArea.style.top = "0";
    textArea.style.left = "0";
    textArea.style.position = "fixed";

    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
      const successful = document.execCommand('copy');
      if (successful) {
        console.log('Fallback: Text copied to clipboard');
      }
    } catch (err) {
      console.error('Fallback: Could not copy text: ', err);
    }

    document.body.removeChild(textArea);
  }
};
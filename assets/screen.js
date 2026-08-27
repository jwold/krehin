(() => {
    const status = document.querySelector('.share-status');
    let statusTimer;

    const announce = (message) => {
        if (!status) return;
        status.textContent = message;
        status.classList.add('share-status--visible');
        window.clearTimeout(statusTimer);
        statusTimer = window.setTimeout(() => {
            status.classList.remove('share-status--visible');
        }, 1800);
    };

    const copyLink = async (url) => {
        if (navigator.clipboard && window.isSecureContext) {
            await navigator.clipboard.writeText(url);
            return;
        }

        const input = document.createElement('textarea');
        input.value = url;
        input.setAttribute('readonly', '');
        input.style.position = 'fixed';
        input.style.opacity = '0';
        document.body.appendChild(input);
        input.select();
        document.execCommand('copy');
        input.remove();
    };

    document.addEventListener('click', async (event) => {
        const button = event.target.closest('.share-button');
        if (!button) return;

        const url = button.dataset.shareUrl;
        const title = button.dataset.shareTitle;

        try {
            if (navigator.share) {
                await navigator.share({title, url});
            } else {
                await copyLink(url);
                announce('Link copied');
            }
        } catch (error) {
            if (error.name !== 'AbortError') {
                announce('Could not share this post');
            }
        }
    });
})();

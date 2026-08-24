document.addEventListener('DOMContentLoaded', () => {
    const urlParams = new URLSearchParams(window.location.search);
    const sessionToken = urlParams.get('t') || '';

    const cameraInput = document.getElementById('cameraInput');
    const fileInput = document.getElementById('fileInput');
    const listHeader = document.getElementById('listHeader');
    const selectedCount = document.getElementById('selectedCount');
    const clearBtn = document.getElementById('clearBtn');
    const previewGrid = document.getElementById('previewGrid');
    const progressSection = document.getElementById('progressSection');
    const progressBar = document.getElementById('progressBar');
    const progressText = document.getElementById('progressText');
    const uploadBtn = document.getElementById('uploadBtn');
    const statusCard = document.getElementById('statusCard');
    const statusIcon = document.getElementById('statusIcon');
    const statusMsg = document.getElementById('statusMsg');

    let selectedFiles = [];

    function updateUI() {
        selectedCount.textContent = selectedFiles.length;
        listHeader.style.display = selectedFiles.length > 0 ? 'flex' : 'none';
        uploadBtn.disabled = selectedFiles.length === 0;

        previewGrid.innerHTML = '';
        selectedFiles.forEach((file, index) => {
            const item = document.createElement('div');
            item.className = 'preview-item';

            const img = document.createElement('img');
            img.src = URL.createObjectURL(file);

            const badge = document.createElement('span');
            badge.className = 'preview-badge';
            badge.textContent = `第 ${index + 1} 页`;

            const rmBtn = document.createElement('button');
            rmBtn.className = 'btn-remove-item';
            rmBtn.textContent = '×';
            rmBtn.onclick = (e) => {
                e.stopPropagation();
                selectedFiles.splice(index, 1);
                updateUI();
            };

            item.appendChild(img);
            item.appendChild(badge);
            item.appendChild(rmBtn);
            previewGrid.appendChild(item);
        });
    }

    function addFiles(files) {
        for (let i = 0; i < files.length; i++) {
            if (selectedFiles.length >= 10) {
                alert('单次最多上传 10 张图片');
                break;
            }
            const file = files[i];
            if (file.type.startsWith('image/')) {
                selectedFiles.push(file);
            }
        }
        updateUI();
    }

    cameraInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            addFiles(e.target.files);
            cameraInput.value = '';
        }
    });

    fileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            addFiles(e.target.files);
            fileInput.value = '';
        }
    });

    clearBtn.addEventListener('click', () => {
        selectedFiles = [];
        updateUI();
        statusCard.style.display = 'none';
    });

    uploadBtn.addEventListener('click', () => {
        if (selectedFiles.length === 0) return;

        if (!sessionToken) {
            alert('缺少有效会话 Token，请重新扫码！');
            return;
        }

        uploadBtn.disabled = true;
        progressSection.style.display = 'block';
        statusCard.style.display = 'none';
        progressBar.style.width = '0%';
        progressText.textContent = '正在准备上传...';

        const formData = new FormData();
        selectedFiles.forEach((file, idx) => {
            formData.append(`file_${idx}`, file, file.name);
        });

        const xhr = new XMLHttpRequest();
        xhr.open('POST', `/api/upload?t=${encodeURIComponent(sessionToken)}`, true);

        xhr.upload.onprogress = (e) => {
            if (e.lengthComputable) {
                const percent = Math.round((e.loaded / e.total) * 100);
                progressBar.style.width = percent + '%';
                progressText.textContent = `正在上传 ${percent}%... (${selectedFiles.length} 张图片)`;
            }
        };

        xhr.onload = () => {
            progressSection.style.display = 'none';
            if (xhr.status === 200) {
                try {
                    const res = JSON.parse(xhr.responseText);
                    if (res.success) {
                        statusCard.className = 'status-card';
                        statusIcon.textContent = '✓';
                        statusMsg.textContent = `成功上传 ${selectedFiles.length} 张图片！电脑端已接收并创建页面。`;
                        statusCard.style.display = 'block';
                        selectedFiles = [];
                        updateUI();
                        return;
                    }
                } catch (e) {}
            }

            statusCard.className = 'status-card error';
            statusIcon.textContent = '✗';
            statusMsg.textContent = `上传失败：${xhr.responseText || '网络异常'}`;
            statusCard.style.display = 'block';
            uploadBtn.disabled = false;
        };

        xhr.onerror = () => {
            progressSection.style.display = 'none';
            statusCard.className = 'status-card error';
            statusIcon.textContent = '✗';
            statusMsg.textContent = '网络连接中断，请确保手机与电脑处于同一局域网 WiFi。';
            statusCard.style.display = 'block';
            uploadBtn.disabled = false;
        };

        xhr.send(formData);
    });
});

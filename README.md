<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nhật HUB - Key System</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        body {
            background: linear-gradient(135deg, #0f2027, #203a43, #2c5364);
            color: white;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .glass-panel {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 4px 30px rgba(0, 0, 0, 0.5);
        }
        .gradient-text {
            background: linear-gradient(to right, #00c6ff, #0072ff);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
    </style>
</head>
<body>

    <div class="glass-panel rounded-2xl p-8 max-w-md w-full mx-4">
        <div class="text-center mb-8">
            <h1 class="text-4xl font-bold font-black tracking-wider gradient-text mb-2">NHẬT HUB</h1>
            <p class="text-gray-400 text-sm">Hệ thống quản lý Key VIP</p>
        </div>

        <div id="alertBox" class="hidden mb-4 p-3 rounded text-center text-sm font-bold"></div>

        <div class="space-y-4">
            <!-- Khu vực Admin nhập liệu -->
            <div>
                <label class="block text-gray-400 text-sm mb-1">Service Name</label>
                <input type="text" id="serviceInput" class="w-full bg-gray-900 border border-gray-700 rounded-lg px-4 py-2 focus:outline-none focus:border-blue-500" placeholder="Nhập Service...">
            </div>
            
            <div>
                <label class="block text-gray-400 text-sm mb-1">Secret Key</label>
                <input type="password" id="secretInput" class="w-full bg-gray-900 border border-gray-700 rounded-lg px-4 py-2 focus:outline-none focus:border-blue-500" placeholder="Nhập mã Secret...">
            </div>

            <div>
                <label class="block text-gray-400 text-sm mb-1">Thời gian tồn tại (Giờ)</label>
                <select id="durationInput" class="w-full bg-gray-900 border border-gray-700 rounded-lg px-4 py-2 focus:outline-none focus:border-blue-500">
                    <option value="12">12 Giờ</option>
                    <option value="24" selected>24 Giờ (1 Ngày)</option>
                    <option value="48">48 Giờ (2 Ngày)</option>
                    <option value="168">1 Tuần</option>
                    <option value="720">1 Tháng (VIP)</option>
                </select>
            </div>

            <!-- Nút tạo Key -->
            <button onclick="generateKey()" class="w-full bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 text-white font-bold py-3 px-4 rounded-lg transition-all transform hover:scale-105 shadow-lg mt-4">
                TẠO KEY GIFT
            </button>
            
            <!-- Khu vực hiện Key -->
            <div id="resultArea" class="hidden mt-6">
                <p class="text-green-400 text-sm mb-2 text-center">Tạo thành công! Copy Key bên dưới:</p>
                <div class="flex items-center space-x-2">
                    <input type="text" id="generatedKey" readonly class="w-full bg-gray-900 text-green-400 font-mono font-bold border border-green-500/50 rounded-lg px-4 py-3 text-center outline-none">
                    <button onclick="copyKey()" class="bg-gray-700 hover:bg-gray-600 px-4 py-3 rounded-lg font-bold">Copy</button>
                </div>
            </div>
        </div>
    </div>

    <script>
        async function generateKey() {
            const service = document.getElementById('serviceInput').value;
            const secret = document.getElementById('secretInput').value;
            const durationHours = document.getElementById('durationInput').value;
            const alertBox = document.getElementById('alertBox');

            if(!service || !secret) {
                showAlert("Vui lòng nhập Service và Secret!", "bg-red-500/20 text-red-400");
                return;
            }

            try {
                const response = await fetch('/api/admin/generate', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ service, secret, durationHours: parseInt(durationHours) })
                });
                
                const data = await response.json();

                if (data.success) {
                    document.getElementById('resultArea').classList.remove('hidden');
                    document.getElementById('generatedKey').value = data.key;
                    showAlert("Tạo Key thành công!", "bg-green-500/20 text-green-400");
                } else {
                    showAlert(data.message, "bg-red-500/20 text-red-400");
                }
            } catch (error) {
                showAlert("Lỗi kết nối đến máy chủ!", "bg-red-500/20 text-red-400");
            }
        }

        function showAlert(msg, classes) {
            const alertBox = document.getElementById('alertBox');
            alertBox.className = `mb-4 p-3 rounded text-center text-sm font-bold ${classes}`;
            alertBox.innerText = msg;
            alertBox.classList.remove('hidden');
        }

        function copyKey() {
            const keyInput = document.getElementById('generatedKey');
            keyInput.select();
            document.execCommand("copy");
            showAlert("Đã copy Key!", "bg-blue-500/20 text-blue-400");
        }
    </script>
</body>
</html>

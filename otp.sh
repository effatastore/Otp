#!/bin/bash
#Crate By: EFFATA
# Prompt for Telegram bot token
read -p "Enter your Telegram bot token: " BOT_TOKEN

# Prompt for seller code
read -p "Enter your seller code: " SELLER_CODE

# Install Python 3 and pip
apt update && apt upgrade -y
apt install -y python3 python3-pip

# Install required Python packages
pip3 install python-telegram-bot requests

# Create the Python script
cat <<EOF > /root/tes.py
import asyncio
import logging
import requests
from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    ConversationHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

# Enable logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)

logger = logging.getLogger(__name__)

# Define states for the conversation
PHONE_NUMBER, REQUEST_OTP, OTP = range(3)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Automatically set the seller code and ask for the phone number."""
    context.user_data['seller_code'] = "$SELLER_CODE"
    await update.message.reply_text('Selamat Datang Di Otp Bot Resseler. Silahkan Masukan Nomer XL/AXIS Anda Format 628xxxx/0819xxxxx:')
    return PHONE_NUMBER

async def phone_number(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Store the phone number, request OTP, and ask for the OTP."""
    context.user_data['phone_number'] = update.message.text
    msisdn = context.user_data['phone_number']
    seller_code = context.user_data['seller_code']

    response = requests.post(
        "https://nomorxlku.my.id/api/req_otp.php",
        data={"msisdn": msisdn, "seller_code": seller_code},
    )

    data = response.json()
    if data['status']:
        context.user_data['auth_id'] = data['data']['auth_id']
        await update.message.reply_text(data['message'] + ' Please enter the OTP you received:')
        return OTP
    else:
        await update.message.reply_text('Failed to request OTP: ' + data['message'])
        return ConversationHandler.END

async def verify_otp(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Verify the OTP and end the conversation."""
    otp = update.message.text
    msisdn = context.user_data['phone_number']
    auth_id = context.user_data['auth_id']

    response = requests.post(
        "https://nomorxlku.my.id/api/ver_otp.php",
        data={"msisdn": msisdn, "auth_id": auth_id, "otp": otp},
    )

    data = response.json()
    if data['status']:
        await update.message.reply_text('OTP verified successfully Silakan Lapor Ke Sellermu: ' + data['message'])
    else:
        await update.message.reply_text('Invalid OTP: ' + data['message'])

    return ConversationHandler.END

def cancel(update: Update, context: ContextTypes.DEFAULT_TYPE) -> int:
    """Cancel the conversation."""
    update.message.reply_text('Operation canceled.')
    return ConversationHandler.END

def main() -> None:
    """Run the bot."""
    application = Application.builder().token("$BOT_TOKEN").build()

    conv_handler = ConversationHandler(
        entry_points=[CommandHandler('start', start)],
        states={
            PHONE_NUMBER: [MessageHandler(filters.TEXT & ~filters.COMMAND, phone_number)],
            OTP: [MessageHandler(filters.TEXT & ~filters.COMMAND, verify_otp)],
        },
        fallbacks=[CommandHandler('cancel', cancel)],
    )

    application.add_handler(conv_handler)

    # Start the bot
    application.run_polling()

def run_asyncio_main():
    try:
        asyncio.run(main())
    except RuntimeError as e:
        if str(e) != "This event loop is already running":
            raise
        # Handle the case where the event loop is already running
        loop = asyncio.get_event_loop()
        loop.run_until_complete(main())

if __name__ == '__main__':
    run_asyncio_main()
EOF

# Replace the placeholder with the actual bot token and seller code
sed -i "s/\$BOT_TOKEN/$BOT_TOKEN/" /root/tes.py
sed -i "s/\$SELLER_CODE/$SELLER_CODE/" /root/tes.py

# Create a systemd service file for the bot
cat <<EOL >/etc/systemd/system/bototp.service
[Unit]
Description=Telegram Bot OTP Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/root
ExecStart=/usr/bin/python3 /root/tes.py
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd daemon
systemctl daemon-reload

# Start and enable the bot service
systemctl start bototp.service
systemctl enable bototp.service
systemctl restart bototp

echo "Installation complete. The bot service is running."

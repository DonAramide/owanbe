# Known Limitations

The following limitations are identified for the current release of Owanbe Enterprise Console:

1. **Auto-Recovery Loop**: Scheduling automatic recovery during maintenance modes requires active Redis state caching.
2. **Third-party Broadcast Gateways**: Live SMTP and Twilio delivery reports must be polled asynchronously.

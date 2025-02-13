import 'package:flutter/material.dart';
import 'esewa_qr_screen.dart'; // Import eSewa QR Screen
import 'khalti_qr_screen.dart'; // Import Khalti QR Screen

class WalletPaymentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Wallet Payment",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.purple.shade700,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade700, Colors.deepPurpleAccent.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🟢 Pay via eSewa
            AnimatedWalletButton(
              text: "Pay via eSewa",
              icon: Icons.payment,
              color: Colors.green,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EsewaQRScreen()),
                );
              },
            ),
            SizedBox(height: 20),

            // 🔵 Pay via Khalti
            AnimatedWalletButton(
              text: "Pay via Khalti",
              icon: Icons.account_balance_wallet,
              color: Colors.blue,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => KhaltiQRScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 🎨 Custom Animated Button
class AnimatedWalletButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const AnimatedWalletButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  _AnimatedWalletButtonState createState() => _AnimatedWalletButtonState();
}

class _AnimatedWalletButtonState extends State<AnimatedWalletButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        child: Container(
          width: 250,
          height: 60,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(2, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                widget.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

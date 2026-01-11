import 'package:flutter/material.dart';
import '../services/auth_services.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  // State
  bool _isLogin = true; // Toggle between Login and Sign Up
  bool _isLoading = false;
  
  // Controllers
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController(); // Only for Sign Up

  void _googleLogin() async {
     setState(() => _isLoading = true);
     try {
      await _auth.signInWithGoogle();
   }
   catch (e) {
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString().split(']').last.trim()}")),
      );
   }
   finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Log In
        await _auth.signIn(
          _emailController.text.trim(), 
          _passController.text.trim()
        );
        // Authentication state change in main.dart will handle navigation
      } else {
        // Sign Up
        await _auth.signUp(
          _emailController.text.trim(),
          _passController.text.trim(),
          _nameController.text.trim(),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString().split(']').last.trim()}")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F0), // Cream background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Image.asset(
                  'assets/icons/final_logo.png',
                  height: 120,    // Adjust height to fit your design
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Fruit Neighbor",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF228B22)),
                ),
                Text(
                  _isLogin ? "Welcome back, neighbor!" : "Join the abundance loop.",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                // NAME FIELD (Sign Up Only)
                if (!_isLogin)
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDec("Your Name"),
                    validator: (v) => v!.isEmpty ? "Please enter a name" : null,
                  ),
                if (!_isLogin) const SizedBox(height: 15),

                // EMAIL FIELD
                TextFormField(
                  controller: _emailController,
                  decoration: _inputDec("Email Address"),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => !v!.contains('@') ? "Invalid email" : null,
                ),
                const SizedBox(height: 15),

                // PASSWORD FIELD
                TextFormField(
                  controller: _passController,
                  decoration: _inputDec("Password"),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? "Password too short" : null,
                ),
                const SizedBox(height: 30),

                // SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF228B22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLogin ? "LOG IN" : "CREATE ACCOUNT",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                  ),
                ),

                // TOGGLE BUTTON
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin 
                      ? "New here? Create an account" 
                      : "Already have an account? Log In",
                    style: const TextStyle(color: Color(0xFF228B22)),
                  ),
                ),
                // TOGGLE BUTTON
                TextButton(
                  onPressed: () => _isLoading ? null : _googleLogin(),
                  child: Text(
                    _isLogin 
                      ? "Sign in with google" 
                      : "Already have an account? Log In",
                    style: const TextStyle(color: Color(0xFF228B22)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
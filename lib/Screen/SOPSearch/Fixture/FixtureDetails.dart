import 'package:flutter/material.dart';
import 'package:overview_app/Screen/SOPSearch/sopSearch.dart';

class FixtureDetails extends StatefulWidget {
  @override
  _FixtureDetailsState createState() => _FixtureDetailsState();
}

class _FixtureDetailsState extends State<FixtureDetails> {
  // Fixture details UI and Display Datas
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),

      // AppBar
      appBar: AppBar(
        title: const Text("Fixture Data"),
        elevation: 0,
        backgroundColor: Colors.white,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => SOPSearch()),
            );
          },
        ),
      ),

      body: Column(
        children: [
          // Search + Filter
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Filter Button
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    // color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.filter_list),
                ),
              ],
            ),
          ),

          // List UI
          Expanded(
            child: ListView.builder(
              itemCount: 5, // dummy count
              itemBuilder: (context, index) {
                return _buildCard();
              },
            ),
          ),
        ],
      ),
    );
  }

  // Card UI
  Widget _buildCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(12),

        // Top (Collapsed View)
        title: const Text(
          "PART NUMBER",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            const Text("DESCRIPTION GOES HERE"),

            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Qty: --"),
                Text("\$----", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),

        // Expanded Content
        children: [
          const Divider(),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Title
                const Text(
                  "Purchasing Updates",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                const SizedBox(height: 10),

                // Notice Item UI (Repeat later with data)
                _buildNoticeItem(),
                _buildNoticeItem(),
                _buildNoticeItem(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Notice / Response UI
  Widget _buildNoticeItem() {
    return Container(
      // color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        // color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Indicator
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            // color: Colors.white,
            decoration: const BoxDecoration(
              // color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 10),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Notice message goes here...",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),

                SizedBox(height: 4),

                Text(
                  "Response / ETA / Status",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

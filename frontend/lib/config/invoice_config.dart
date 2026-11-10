/// Data tetap di invoice. Ubah di sini bila alamat atau rekening berganti.
class InvoiceConfig {
  InvoiceConfig._();

  // Kop surat (tampil di setiap halaman)
  static const companyName = 'CV. KARYA PUTRA BUMI';
  static const companyAddress =
      'Jl. Cakalang nomor 20F, Kec Blimbing, Kel Polowijen, Kota Malang';
  static const companyContact =
      'Telp : 082231031037, Email : karyaputrabumi318@gmail.com';
  static const logoAsset = 'assets/images/kpb.png';

  // Alamat penerbit di blok Nomor/Tanggal
  static const issuerAddress = 'Jl. Cakalang No. 102 Kota Malang';

  // Pelanggan (sama untuk semua cabang)
  static const customerName = 'PT. KACEBE MURNI TRANSPORT';
  static const customerAddress =
      'Jl. Raden Intan No.8, Arjosari, Kec. Blimbing, Kota Malang, Jawa Timur';

  // Pembayaran
  static const bankName = 'BCA';
  static const bankAccount = '3151255891';
  static const bankHolder = 'WAHYU REKSO SAYOKO';

  // Teks
  static const serviceText = 'Cuci (Eksterior-Interior) Bus Mtrans';
  static const city = 'Kota Malang';
  static const closingText =
      'Demikian tagihan ini saya sampaikan. Atas perhatian dan kerja samanya, saya ucapkan terima kasih.';
  static const thanksText = 'Terimakasih atas Kerjasamanya';

  /// Jatuh tempo default = tanggal invoice + sekian hari.
  static const defaultDueDays = 7;
}

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('scan_histories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->onDelete('cascade');
            $table->text('url');
            $table->string('domain')->index();
            $table->string('verdict')->index(); // DANGEROUS, SUSPICIOUS, SAFE
            $table->integer('risk_score')->default(0);
            $table->json('threat_details')->nullable();
            $table->string('google_safe_browsing_status')->default('untested');
            $table->string('virustotal_status')->default('untested');
            $table->string('heuristics_status')->default('passed');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('scan_histories');
    }
};

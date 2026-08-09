<?php

namespace App\Http\Controllers;

abstract class Controller
{
    /**
     * Standard JSON success response builder.
     */
    protected function successResponse($data = null, string $message = 'Success', int $code = 200)
    {
        return response()->json([
            'status' => 'success',
            'message' => $message,
            'data' => $data,
        ], $code);
    }

    /**
     * Standard JSON error response builder.
     */
    protected function errorResponse(string $message = 'An error occurred', int $code = 400, $errors = null)
    {
        return response()->json([
            'status' => 'error',
            'message' => $message,
            'errors' => $errors,
        ], $code);
    }
}
